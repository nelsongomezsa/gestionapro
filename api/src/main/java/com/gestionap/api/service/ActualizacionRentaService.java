package com.gestionap.api.service;

import com.gestionap.api.domain.ActualizacionRenta;
import com.gestionap.api.domain.ActualizacionRenta.Indice;
import com.gestionap.api.domain.Contrato;
import com.gestionap.api.repository.ActualizacionRentaRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.ActualizacionRentaDtos.Confirmacion;
import com.gestionap.api.web.dto.ActualizacionRentaDtos.Historial;
import com.gestionap.api.web.dto.ActualizacionRentaDtos.Propuesta;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.List;
import java.util.Optional;

/**
 * Actualización anual de la renta. Orientativa: el propietario revisa la propuesta y la confirma.
 *
 * Índice recomendado según la fecha del contrato (se puede cambiar si el contrato dice otra cosa):
 * - Firmado desde el 26-05-2023 (entrada en vigor de la Ley 12/2023): IRAV del INE, el índice
 *   de referencia de la disposición adicional undécima de la LAU.
 * - Anterior: IPC del INE, lo habitual en las cláusulas de esos contratos.
 * El dato es el último publicado en la fecha de la actualización (LAU, art. 18): el INE publica
 * el de un mes hacia mediados del siguiente, así que se toma el del mes anterior desde el día 15 y,
 * antes, el de dos meses atrás (la API del INE no da la fecha de publicación de cada dato).
 *
 * Tope: el art. 18.1 de la LAU, en la redacción del Real Decreto-ley 29/2026 (BOE-A-2026-20823),
 * dice que "en todo caso" la subida no puede superar el IRAV. Por prudencia se aplica a todos los
 * contratos (también a los anteriores a la Ley 12/2023, cuyo encaje el RDL deja menos claro) y se
 * puede desactivar con gestionap.renta.tope-irav=false si la norma cambia.
 */
@Service
public class ActualizacionRentaService {

    static final LocalDate LEY_12_2023 = LocalDate.of(2023, 5, 26);
    /** Se puede preparar hasta 30 días antes del aniversario. */
    static final int DIAS_ANTELACION = 30;

    private final ActualizacionRentaRepository historial;
    private final ContratoService contratos;
    private final IndicesOficiales indices;
    private final ActividadService actividad;
    private final boolean topeIrav;

    public ActualizacionRentaService(ActualizacionRentaRepository historial, ContratoService contratos,
                                     IndicesOficiales indices, ActividadService actividad,
                                     @Value("${gestionap.renta.tope-irav:true}") boolean topeIrav) {
        this.historial = historial;
        this.contratos = contratos;
        this.indices = indices;
        this.actividad = actividad;
        this.topeIrav = topeIrav;
    }

    /** Máximo aplicable con ese índice en esa fecha (null si no hay dato) y si lo ha limitado el IRAV. */
    record Maximo(BigDecimal porcentaje, String periodo, String fuente, boolean limitado) {}

    Maximo maximo(Indice indice, LocalDate fecha, BigDecimal pactado) {
        YearMonth mes = mesDelDato(fecha);
        BigDecimal pct = pactado;
        String periodo = null;
        String fuente = "Porcentaje pactado en el contrato";
        if (indice != Indice.PACTADO) {
            var dato = indices.ultimoHasta(indice.name(), mes);
            if (dato.isEmpty()) return new Maximo(null, null, "Sin conexión con el INE: introduce el porcentaje", false);
            pct = dato.get().variacionAnual();
            periodo = dato.get().periodo().toString();
            fuente = fuente(indice, dato.get());
        }
        if (pct == null || !topeIrav || indice == Indice.IRAV) return new Maximo(pct, periodo, fuente, false);
        var irav = indices.ultimoHasta(Indice.IRAV.name(), mes);
        if (irav.isPresent() && pct.compareTo(irav.get().variacionAnual()) > 0) {
            return new Maximo(irav.get().variacionAnual(), irav.get().periodo().toString(),
                    fuente + "; limitado al " + fuente(Indice.IRAV, irav.get()) + " (LAU, art. 18.1)", true);
        }
        return new Maximo(pct, periodo, fuente, false);
    }

    @Transactional(readOnly = true)
    public Propuesta propuesta(Integer idContrato, Indice pedido, UsuarioAutenticado actor) {
        return propuesta(contratos.cargarVisible(idContrato, actor), pedido, LocalDate.now());
    }

    Propuesta propuesta(Contrato c, Indice pedido, LocalDate hoy) {
        Indice recomendado = recomendado(c);
        Indice indice = pedido != null ? pedido : recomendado;
        String motivo = recomendado == Indice.IRAV
                ? "Contrato firmado desde el 26-05-2023 (Ley 12/2023): índice de referencia IRAV del INE."
                : "Contrato anterior al 26-05-2023: lo habitual es el IPC del INE; revisa la cláusula de tu contrato.";
        Optional<LocalDate> pendiente = aniversarioPendiente(c, hoy);
        LocalDate fecha = pendiente.orElseGet(() -> siguienteAniversario(c, hoy));
        BigDecimal renta = c.getPrecioMensual();
        String aviso = "Orientativo: aplica lo que diga la cláusula de actualización de tu contrato (si no la tiene, no se actualiza) "
                + "y nunca más que el IRAV (LAU, art. 18.1). Puedes aplicar menos que el máximo.";
        if (fecha.isAfter(c.getFechaFin())) {
            return new Propuesta(false, null, indice, recomendado, null, null, false, renta, null,
                    null, motivo, "El contrato termina antes del próximo aniversario: no hay actualización pendiente.");
        }
        Maximo max = maximo(indice, fecha, null);
        return new Propuesta(pendiente.isPresent(), fecha, indice, recomendado, max.periodo(), max.porcentaje(), max.limitado(),
                renta, max.porcentaje() == null ? null : aplicar(renta, max.porcentaje()),
                indice == Indice.PACTADO ? "Porcentaje pactado en el contrato" : max.fuente(), motivo, aviso);
    }

    @Transactional
    public Historial confirmar(Integer idContrato, Confirmacion req, UsuarioAutenticado actor) {
        Contrato c = contratos.cargarVisible(idContrato, actor);
        LocalDate hoy = LocalDate.now();
        LocalDate fecha = req.fechaEfecto();
        if (!esAniversario(c, fecha) || fecha.isAfter(hoy.plusDays(DIAS_ANTELACION)) || fecha.isAfter(c.getFechaFin())) {
            throw ApiException.badRequest("FECHA_ACTUALIZACION_NO_VALIDA",
                    "La actualización es en un aniversario del contrato, como mucho dentro de " + DIAS_ANTELACION + " días");
        }
        if (historial.existsByContratoIdAndFechaEfecto(c.getId(), fecha)) {
            throw ApiException.conflicto("YA_ACTUALIZADA", "La renta de esa anualidad ya está actualizada");
        }
        if (req.indice() == Indice.PACTADO && req.porcentaje() == null) {
            throw ApiException.badRequest("FALTA_PORCENTAJE", "Indica el porcentaje pactado");
        }
        Maximo max = maximo(req.indice(), fecha, req.indice() == Indice.PACTADO ? req.porcentaje() : null);
        BigDecimal pct;
        String fuente = max.fuente();
        if (max.porcentaje() == null) {
            // Sin dato del INE: el porcentaje que ha revisado el propietario.
            if (req.porcentaje() == null) throw ApiException.badRequest("FALTA_PORCENTAJE", "No hay dato del INE: indica el porcentaje");
            pct = req.porcentaje();
            fuente = req.indice() + " del INE introducido por el propietario";
        } else if (req.porcentaje() != null && req.porcentaje().compareTo(max.porcentaje()) < 0) {
            // Se puede aplicar menos que el máximo, nunca más.
            pct = req.porcentaje();
            fuente = "Por debajo del máximo (" + max.porcentaje().toPlainString() + " %): " + max.fuente();
        } else {
            pct = max.porcentaje();
        }
        String periodo = max.periodo();
        ActualizacionRenta a = new ActualizacionRenta();
        a.setContrato(c);
        a.setFechaEfecto(fecha);
        a.setIndice(req.indice());
        a.setPeriodoIndice(periodo);
        a.setPorcentaje(pct);
        a.setRentaAnterior(c.getPrecioMensual());
        a.setRentaNueva(aplicar(c.getPrecioMensual(), pct));
        a.setFuente(fuente);
        a.setIdUsuario(actor.id());
        a.setFechaConfirmacion(LocalDateTime.now());
        try {
            historial.saveAndFlush(a);
        } catch (DataIntegrityViolationException e) {
            // Otra confirmación de la misma anualidad se ha adelantado (clave única contrato + fecha).
            throw ApiException.conflicto("YA_ACTUALIZADA", "La renta de esa anualidad ya está actualizada");
        }
        c.setPrecioMensual(a.getRentaNueva());
        actividad.registrar(actor.id(), "ACTUALIZAR_RENTA", c.getInquilino().getNombreCompleto() + " · "
                + a.getRentaAnterior().toPlainString() + " → " + a.getRentaNueva().toPlainString() + " € (" + req.indice() + ")");
        return Historial.de(a);
    }

    @Transactional(readOnly = true)
    public List<Historial> historial(Integer idContrato, UsuarioAutenticado actor) {
        contratos.cargarVisible(idContrato, actor);
        return historial.findByContratoIdOrderByFechaEfectoDesc(idContrato).stream().map(Historial::de).toList();
    }

    static Indice recomendado(Contrato c) {
        return c.getFechaInicio().isBefore(LEY_12_2023) ? Indice.IPC : Indice.IRAV;
    }

    /** Último dato publicado en esa fecha: el del mes anterior desde el día 15; antes, el de dos meses atrás. */
    static YearMonth mesDelDato(LocalDate fecha) {
        return YearMonth.from(fecha).minusMonths(fecha.getDayOfMonth() >= 15 ? 1 : 2);
    }

    static BigDecimal aplicar(BigDecimal renta, BigDecimal pct) {
        return renta.multiply(BigDecimal.ONE.add(pct.movePointLeft(2))).setScale(2, RoundingMode.HALF_UP);
    }

    private static boolean esAniversario(Contrato c, LocalDate fecha) {
        int anios = fecha.getYear() - c.getFechaInicio().getYear();
        return anios >= 1 && c.getFechaInicio().plusYears(anios).equals(fecha);
    }

    /** El aniversario más reciente que ya toca (o toca en 30 días) y no se ha aplicado. */
    private Optional<LocalDate> aniversarioPendiente(Contrato c, LocalDate hoy) {
        LocalDate limite = hoy.plusDays(DIAS_ANTELACION);
        LocalDate candidato = null;
        for (int n = 1; !c.getFechaInicio().plusYears(n).isAfter(limite); n++) {
            LocalDate f = c.getFechaInicio().plusYears(n);
            if (!f.isAfter(c.getFechaFin())) candidato = f;
        }
        if (candidato == null || historial.existsByContratoIdAndFechaEfecto(c.getId(), candidato)) return Optional.empty();
        return Optional.of(candidato);
    }

    private static LocalDate siguienteAniversario(Contrato c, LocalDate hoy) {
        int n = 1;
        while (!c.getFechaInicio().plusYears(n).isAfter(hoy.plusDays(DIAS_ANTELACION))) n++;
        return c.getFechaInicio().plusYears(n);
    }

    private static String fuente(Indice indice, IndicesOficiales.Dato d) {
        String nombre = indice == Indice.IRAV ? "IRAV (Índice de Referencia de Arrendamientos de Vivienda)" : "IPC general";
        return "INE · " + nombre + ", variación anual de " + Textos.mes(d.periodo()) + " (serie " + d.serie() + ")";
    }
}
