package com.gestionap.api.service;

import com.gestionap.api.domain.*;
import com.gestionap.api.repository.*;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.dto.ContratoResponse;
import com.gestionap.api.web.dto.PagoResponse;
import com.gestionap.api.web.dto.PanelDtos.*;
import com.gestionap.api.web.dto.PisoResponse;
import com.gestionap.api.web.dto.ResumenPagosResponse;
import org.springframework.data.domain.Limit;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Inicio, Estadísticas y Calendario (DashboardController, EstadisticasController y
 * CalendarioController del escritorio). Allí las consultas eran globales y los meses salían
 * con DATE_FORMAT('%b'), en el idioma del servidor; aquí se filtra por propietario y los
 * meses van siempre en español.
 */
@Service
public class PanelService {

    private static final int ACTIVIDAD_RECIENTE = 8;

    private final HabitacionRepository habitaciones;
    private final ContratoRepository contratos;
    private final PagoRepository pagos;
    private final IncidenciaRepository incidencias;
    private final InquilinoRepository inquilinos;
    private final ActividadRepository actividad;
    private final PisoService pisos;
    private final PagoService pagoService;
    private final ControlAcceso acceso;

    public PanelService(HabitacionRepository habitaciones, ContratoRepository contratos, PagoRepository pagos,
                        IncidenciaRepository incidencias, InquilinoRepository inquilinos, ActividadRepository actividad,
                        PisoService pisos, PagoService pagoService, ControlAcceso acceso) {
        this.habitaciones = habitaciones;
        this.contratos = contratos;
        this.pagos = pagos;
        this.incidencias = incidencias;
        this.inquilinos = inquilinos;
        this.actividad = actividad;
        this.pisos = pisos;
        this.pagoService = pagoService;
        this.acceso = acceso;
    }

    @Transactional(readOnly = true)
    public DashboardResponse dashboard(UsuarioAutenticado actor) {
        Integer prop = acceso.filtroPropietario(actor);
        LocalDate hoy = LocalDate.now();
        YearMonth mes = YearMonth.from(hoy);

        List<Contrato> todos = contratos.buscar(prop, null, null);
        List<Contrato> activos = todos.stream().filter(c -> c.estaActivoEn(hoy)).toList();
        List<ImporteMes> seisMeses = ingresosPorMes(prop, mes.minusMonths(5), mes);
        BigDecimal cobrado = seisMeses.getLast().importe();
        BigDecimal anterior = seisMeses.get(seisMeses.size() - 2).importe();
        var pendientesInc = incidencias.buscar(prop, null, null, Set.of(EstadoIncidencia.pendiente, EstadoIncidencia.en_proceso));
        BigDecimal cashFlow = pisos.listar(actor).stream()
                .map(PisoResponse::metricas).filter(Objects::nonNull)
                .map(PisoResponse.Metricas::cashFlowMensual).reduce(BigDecimal.ZERO, BigDecimal::add);
        List<ContratoResponse> proximos = activos.stream()
                .filter(c -> NivelVencimiento.de(c.getFechaFin(), hoy) != NivelVencimiento.NORMAL)
                .sorted(Comparator.comparing(Contrato::getFechaFin))
                .map(c -> ContratoResponse.de(c, hoy)).toList();
        Ocupacion ocupacion = ocupacion(prop);
        long incPendientes = pendientesInc.stream().filter(i -> i.getEstado() == EstadoIncidencia.pendiente).count();

        return new DashboardResponse(ocupacion,
                inquilinos.visiblesPara(prop).size(), activos.size(), incPendientes,
                pendientesInc.size() - incPendientes, cobrado, anterior, variacion(cobrado, anterior),
                activos.stream().map(Contrato::getPrecioMensual).reduce(BigDecimal.ZERO, BigDecimal::add),
                cashFlow, seisMeses, alertas(ocupacion, proximos, incPendientes), proximos,
                actividadReciente(actor, ACTIVIDAD_RECIENTE));
    }

    @Transactional(readOnly = true)
    public EstadisticasResponse estadisticas(UsuarioAutenticado actor) {
        Integer prop = acceso.filtroPropietario(actor);
        YearMonth mes = YearMonth.now();
        int anio = mes.getYear();
        BigDecimal esteAnio = suma(pagos.buscar(prop, null, LocalDate.of(anio, 1, 1), LocalDate.of(anio, 12, 31)));
        BigDecimal anioPasado = suma(pagos.buscar(prop, null, LocalDate.of(anio - 1, 1, 1), LocalDate.of(anio - 1, 12, 31)));

        YearMonth desde = mes.minusMonths(5);
        Map<YearMonth, Long> porMes = incidencias.buscar(prop, null, null, EnumSet.allOf(EstadoIncidencia.class)).stream()
                .map(i -> YearMonth.from(i.getFecha())).filter(m -> !m.isBefore(desde) && !m.isAfter(mes))
                .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()));
        List<ConteoMes> incidencias6 = meses(desde, mes)
                .map(m -> new ConteoMes(m.toString(), Textos.mesCorto(m), porMes.getOrDefault(m, 0L))).toList();

        return new EstadisticasResponse(ingresosPorMes(prop, mes.minusMonths(11), mes), ocupacion(prop), incidencias6,
                esteAnio, anioPasado, variacion(esteAnio, anioPasado), anio);
    }

    /** Calendario del mes: estado de cada día como en el escritorio, pagos y fines de contrato. */
    @Transactional(readOnly = true)
    public CalendarioResponse calendario(YearMonth mes, UsuarioAutenticado actor) {
        Integer prop = acceso.filtroPropietario(actor);
        LocalDate hoy = LocalDate.now();
        LocalDate inicio = mes.atDay(1);
        LocalDate fin = mes.atEndOfMonth();
        ResumenPagosResponse resumen = pagoService.resumen(mes, actor);
        boolean hayContratosSinPagar = !resumen.pendientes().isEmpty();

        Map<LocalDate, List<PagoResponse>> pagosPorDia = pagos.buscar(prop, null, inicio, fin).stream()
                .map(PagoResponse::de).collect(Collectors.groupingBy(PagoResponse::fechaPago));
        Map<LocalDate, List<ContratoResponse>> finesPorDia = contratos.buscar(prop, null, null).stream()
                .filter(c -> !c.getFechaFin().isBefore(inicio) && !c.getFechaFin().isAfter(fin))
                .map(c -> ContratoResponse.de(c, hoy)).collect(Collectors.groupingBy(ContratoResponse::fechaFin));

        List<DiaCalendario> dias = inicio.datesUntil(fin.plusDays(1)).map(dia -> {
            List<PagoResponse> delDia = pagosPorDia.getOrDefault(dia, List.of());
            String estado;
            if (!delDia.isEmpty()) estado = "PAGADO";
            else if (hayContratosSinPagar && dia.getDayOfMonth() <= 5) estado = dia.isAfter(hoy) ? "ESPERADO" : "VENCIDO";
            else estado = "NORMAL";
            return new DiaCalendario(dia, estado, delDia, finesPorDia.getOrDefault(dia, List.of()));
        }).toList();

        return new CalendarioResponse(mes.toString(), resumen.nombreMes(), resumen.esperado(), resumen.cobrado(),
                resumen.pendiente(), dias);
    }

    /** Actividad reciente: el admin ve la de todos (como el escritorio); un propietario, la suya. */
    @Transactional(readOnly = true)
    public List<ActividadResponse> actividadReciente(UsuarioAutenticado actor, int limite) {
        var lista = actor.esAdmin()
                ? actividad.findAllByOrderByFechaDescIdDesc(Limit.of(limite))
                : actividad.findByIdUsuarioOrderByFechaDescIdDesc(actor.id(), Limit.of(limite));
        return lista.stream().map(ActividadResponse::de).toList();
    }

    /** Ingresos cobrados de un piso en los últimos 12 meses (gráfico del detalle de piso del escritorio). */
    @Transactional(readOnly = true)
    public List<ImporteMes> ingresosPiso(Integer idPiso, UsuarioAutenticado actor) {
        acceso.pisoVisible(idPiso, actor);
        YearMonth hasta = YearMonth.now();
        YearMonth desde = hasta.minusMonths(11);
        Map<YearMonth, BigDecimal> porMes = pagos.buscar(null, null, desde.atDay(1), hasta.atEndOfMonth()).stream()
                .filter(p -> p.getContrato().getHabitacion().getPiso().getId().equals(idPiso))
                .collect(Collectors.groupingBy(p -> YearMonth.from(p.getFechaPago()),
                        Collectors.reducing(BigDecimal.ZERO, Pago::getCantidad, BigDecimal::add)));
        return meses(desde, hasta)
                .map(m -> new ImporteMes(m.toString(), Textos.mesCorto(m), porMes.getOrDefault(m, BigDecimal.ZERO))).toList();
    }

    Ocupacion ocupacion(Integer prop) {
        Map<EstadoHabitacion, Long> porEstado = habitaciones.buscar(prop, null, null).stream()
                .collect(Collectors.groupingBy(Habitacion::getEstado, () -> new EnumMap<>(EstadoHabitacion.class), Collectors.counting()));
        long alquiladas = porEstado.getOrDefault(EstadoHabitacion.alquilada, 0L);
        long total = porEstado.values().stream().mapToLong(Long::longValue).sum();
        double pct = total == 0 ? 0 : BigDecimal.valueOf(alquiladas * 100.0 / total).setScale(2, RoundingMode.HALF_UP).doubleValue();
        String salud = pct >= 75 ? "Sistema saludable" : pct >= 40 ? "Ocupación media" : "Baja ocupación";
        return new Ocupacion(total, alquiladas, porEstado.getOrDefault(EstadoHabitacion.disponible, 0L),
                porEstado.getOrDefault(EstadoHabitacion.mantenimiento, 0L), pct, salud);
    }

    List<ImporteMes> ingresosPorMes(Integer prop, YearMonth desde, YearMonth hasta) {
        Map<YearMonth, BigDecimal> porMes = pagos.buscar(prop, null, desde.atDay(1), hasta.atEndOfMonth()).stream()
                .collect(Collectors.groupingBy(p -> YearMonth.from(p.getFechaPago()),
                        Collectors.reducing(BigDecimal.ZERO, Pago::getCantidad, BigDecimal::add)));
        return meses(desde, hasta)
                .map(m -> new ImporteMes(m.toString(), Textos.mesCorto(m), porMes.getOrDefault(m, BigDecimal.ZERO))).toList();
    }

    private static List<Alerta> alertas(Ocupacion ocupacion, List<ContratoResponse> proximos, long incidenciasPendientes) {
        List<Alerta> alertas = new ArrayList<>();
        if (!proximos.isEmpty()) {
            String nombres = proximos.stream().map(c -> c.inquilino().nombre()).collect(Collectors.joining(", "));
            alertas.add(new Alerta("CONTRATOS_POR_VENCER",
                    proximos.size() == 1 ? "1 contrato vence en menos de 30 días" : proximos.size() + " contratos vencen próximamente",
                    nombres, proximos.stream().anyMatch(c -> c.vencimiento() == NivelVencimiento.CRITICO) ? "negativo" : "aviso"));
        }
        if (incidenciasPendientes > 0) {
            alertas.add(new Alerta("INCIDENCIAS_PENDIENTES",
                    incidenciasPendientes == 1 ? "1 incidencia pendiente" : incidenciasPendientes + " incidencias pendientes",
                    "Sin empezar a resolver", "aviso"));
        }
        if (ocupacion.habitaciones() > 0 && ocupacion.porcentaje() < 75) {
            alertas.add(new Alerta("OCUPACION", ocupacion.salud(),
                    ocupacion.disponibles() + " habitaciones libres y " + ocupacion.mantenimiento() + " en mantenimiento",
                    ocupacion.porcentaje() < 40 ? "negativo" : "aviso"));
        }
        return alertas;
    }

    private static Double variacion(BigDecimal actual, BigDecimal anterior) {
        if (anterior.signum() == 0) return null;
        return actual.subtract(anterior).divide(anterior, 4, RoundingMode.HALF_UP).multiply(BigDecimal.valueOf(100)).doubleValue();
    }

    private static BigDecimal suma(List<Pago> lista) {
        return lista.stream().map(Pago::getCantidad).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static Stream<YearMonth> meses(YearMonth desde, YearMonth hasta) {
        return Stream.iterate(desde, m -> !m.isAfter(hasta), m -> m.plusMonths(1));
    }
}
