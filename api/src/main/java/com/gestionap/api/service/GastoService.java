package com.gestionap.api.service;

import com.gestionap.api.domain.EstadoIncidencia;
import com.gestionap.api.domain.Gasto;
import com.gestionap.api.domain.Habitacion;
import com.gestionap.api.domain.Incidencia;
import com.gestionap.api.domain.Piso;
import com.gestionap.api.repository.GastoRepository;
import com.gestionap.api.repository.HabitacionRepository;
import com.gestionap.api.repository.IncidenciaRepository;
import com.gestionap.api.repository.PisoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.GastoDtos.GastoRequest;
import com.gestionap.api.web.dto.GastoDtos.GastoResponse;
import com.gestionap.api.web.dto.GastoDtos.ResumenGastos;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Collection;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Gastos reales de los pisos y facturas asociadas. */
@Service
public class GastoService {

    private final GastoRepository gastos;
    private final PisoRepository pisos;
    private final HabitacionRepository habitaciones;
    private final IncidenciaRepository incidencias;
    private final ControlAcceso acceso;
    private final ArchivoService archivos;
    private final ActividadService actividad;

    public GastoService(GastoRepository gastos, PisoRepository pisos, HabitacionRepository habitaciones,
                        IncidenciaRepository incidencias, ControlAcceso acceso, ArchivoService archivos,
                        ActividadService actividad) {
        this.gastos = gastos;
        this.pisos = pisos;
        this.habitaciones = habitaciones;
        this.incidencias = incidencias;
        this.acceso = acceso;
        this.archivos = archivos;
        this.actividad = actividad;
    }

    /** Lista gastos visibles y sincroniza los costes de incidencias resueltas. */
    @Transactional
    public ResumenGastos listar(Integer idPiso, Integer anio, UsuarioAutenticado actor) {
        List<Piso> visibles = idPiso != null ? List.of(acceso.pisoVisible(idPiso, actor))
                : actor.esAdmin() ? pisos.findAllByOrderByDireccionAsc()
                : pisos.findByPropietarioIdOrderByDireccionAsc(actor.id());
        List<Integer> ids = visibles.stream().map(Piso::getId).toList();
        sincronizar(ids);
        LocalDate desde = anio == null ? null : LocalDate.of(anio, 1, 1);
        LocalDate hasta = anio == null ? null : LocalDate.of(anio, 12, 31);
        List<GastoResponse> lista = gastos.buscar(acceso.filtroPropietario(actor), idPiso, desde, hasta)
                .stream().map(GastoResponse::de).toList();
        BigDecimal total = lista.stream().map(GastoResponse::importe).reduce(BigDecimal.ZERO, BigDecimal::add);
        BigDecimal deducible = lista.stream().filter(GastoResponse::deducible).map(GastoResponse::importe)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        return new ResumenGastos(lista, total, deducible);
    }

    /** Crea un gasto manual. */
    @Transactional
    public GastoResponse crear(GastoRequest req, UsuarioAutenticado actor) {
        Piso piso = acceso.pisoVisible(req.idPiso(), actor);
        validarFecha(req.fecha());
        Gasto gasto = new Gasto();
        gasto.setPiso(piso);
        aplicar(gasto, req);
        gastos.save(gasto);
        actividad.registrar(actor.id(), "CREAR_GASTO", gasto.getConcepto() + " · " + gasto.getImporte() + " €");
        return GastoResponse.de(gasto);
    }

    /** Actualiza un gasto manual. */
    @Transactional
    public GastoResponse actualizar(Integer id, GastoRequest req, UsuarioAutenticado actor) {
        Gasto gasto = cargarVisible(id, actor);
        if (gasto.getIdIncidencia() != null && req.importe().compareTo(gasto.getImporte()) != 0) {
            throw ApiException.conflicto("GASTO_DE_INCIDENCIA", "Cambia el coste en la incidencia");
        }
        Piso piso = acceso.pisoVisible(req.idPiso(), actor);
        validarFecha(req.fecha());
        gasto.setPiso(piso);
        aplicar(gasto, req);
        return GastoResponse.de(gasto);
    }

    /** Borra un gasto manual y su factura. */
    @Transactional
    public void borrar(Integer id, UsuarioAutenticado actor) {
        Gasto gasto = cargarVisible(id, actor);
        if (gasto.getIdIncidencia() != null) {
            throw ApiException.conflicto("GASTO_DE_INCIDENCIA", "Cambia el coste en la incidencia");
        }
        archivos.borrar(gasto.getFacturaRuta());
        gastos.delete(gasto);
        actividad.registrar(actor.id(), "BORRAR_GASTO", "Gasto #" + id + " · " + gasto.getConcepto());
    }

    /** Guarda una factura validada por su firma real. */
    @Transactional
    public GastoResponse subirFactura(Integer id, MultipartFile archivo, UsuarioAutenticado actor) {
        Gasto gasto = cargarVisible(id, actor);
        ArchivoService.Guardado guardado = archivos.guardar("facturas", archivo);
        archivos.borrar(gasto.getFacturaRuta());
        gasto.setFacturaRuta(guardado.ruta());
        gasto.setFacturaTipo(guardado.tipo());
        return GastoResponse.de(gasto);
    }

    /** Devuelve el contenido de la factura. */
    @Transactional(readOnly = true)
    public ArchivoService.Contenido factura(Integer id, UsuarioAutenticado actor) {
        Gasto gasto = cargarVisible(id, actor);
        if (gasto.getFacturaRuta() == null) {
            throw ApiException.noEncontrado("Factura");
        }
        return archivos.leer(gasto.getFacturaRuta(), gasto.getFacturaTipo());
    }

    /** Suma gastos por piso y categoría de los últimos doce meses. */
    @Transactional(readOnly = true)
    public Map<Integer, Map<Gasto.Categoria, BigDecimal>> gastosRealesUltimoAnio(Collection<Integer> idPisos) {
        if (idPisos.isEmpty()) {
            return Map.of();
        }
        LocalDate hoy = LocalDate.now();
        LocalDate desde = hoy.minusMonths(12);
        Map<Integer, Map<Gasto.Categoria, BigDecimal>> resultado = new HashMap<>();
        for (Object[] fila : gastos.sumarPorPisoYCategoria(idPisos, desde, hoy)) {
            resultado.computeIfAbsent((Integer) fila[0], k -> new EnumMap<>(Gasto.Categoria.class))
                    .put((Gasto.Categoria) fila[1], (BigDecimal) fila[2]);
        }
        return resultado;
    }

    private void sincronizar(List<Integer> idsPiso) {
        if (idsPiso.isEmpty()) {
            return;
        }
        for (Incidencia incidencia : incidencias.resueltasConCoste(idsPiso, EstadoIncidencia.resuelta)) {
            Gasto gasto = gastos.findByIdIncidencia(incidencia.getId()).orElseGet(() -> {
                Gasto nuevo = new Gasto();
                nuevo.setPiso(incidencia.getHabitacion().getPiso());
                nuevo.setIdIncidencia(incidencia.getId());
                nuevo.setCategoria(Gasto.Categoria.REPARACION);
                nuevo.setFecha(incidencia.getFecha());
                nuevo.setDeducible(true);
                return nuevo;
            });
            gasto.setImporte(incidencia.getCosteReparacion());
            gasto.setHabitacion(incidencia.getHabitacion());
            String concepto = "Incidencia: " + incidencia.getDescripcion();
            gasto.setConcepto(concepto.substring(0, Math.min(150, concepto.length())));
            gastos.save(gasto);
        }
    }

    private Gasto cargarVisible(Integer id, UsuarioAutenticado actor) {
        return gastos.buscar(acceso.filtroPropietario(actor), null, null, null).stream()
                .filter(g -> g.getId().equals(id)).findFirst().orElseThrow(() -> ApiException.noEncontrado("Gasto"));
    }

    private void aplicar(Gasto gasto, GastoRequest req) {
        gasto.setHabitacion(req.idHabitacion() == null ? null : habitaciones.findConPisoById(req.idHabitacion())
                .filter(h -> h.getPiso().getId().equals(req.idPiso()))
                .orElseThrow(() -> ApiException.badRequest("HABITACION_NO_VALIDA", "La habitación no pertenece al piso")));
        gasto.setCategoria(req.categoria());
        gasto.setConcepto(req.concepto().trim());
        gasto.setImporte(req.importe());
        gasto.setFecha(req.fecha());
        gasto.setDeducible(req.deducible());
        gasto.setFechaAlta(gasto.getFechaAlta() == null ? java.time.LocalDateTime.now() : gasto.getFechaAlta());
    }

    private static void validarFecha(LocalDate fecha) {
        if (fecha.isAfter(LocalDate.now())) {
            throw ApiException.badRequest("FECHA_NO_VALIDA", "La fecha no puede ser futura");
        }
    }
}
