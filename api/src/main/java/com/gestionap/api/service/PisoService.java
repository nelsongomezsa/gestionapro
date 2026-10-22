package com.gestionap.api.service;

import com.gestionap.api.domain.DatosPiso;
import com.gestionap.api.domain.EstadoHabitacion;
import com.gestionap.api.domain.Piso;
import com.gestionap.api.repository.*;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.CiudadResponse;
import com.gestionap.api.web.dto.DatosFinancierosDto;
import com.gestionap.api.web.dto.PisoRequest;
import com.gestionap.api.web.dto.PisoResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.*;

/**
 * CRUD de pisos. Un PROPIETARIO solo ve y modifica los suyos; un ADMIN, todos.
 * Las métricas (rentabilidad, cash flow, cash-on-cash...) salen de
 * CalculadoraFinancieraPiso con las mismas entradas que el escritorio: los
 * datos de DatosPiso y, como ingresos, las rentas de los contratos activos.
 */
@Service
public class PisoService {

    private final PisoRepository pisos;
    private final CiudadRepository ciudades;
    private final HabitacionRepository habitaciones;
    private final ContratoRepository contratos;
    private final UsuarioRepository usuarios;
    private final ActividadService actividad;

    public PisoService(PisoRepository pisos, CiudadRepository ciudades, HabitacionRepository habitaciones,
                       ContratoRepository contratos, UsuarioRepository usuarios, ActividadService actividad) {
        this.pisos = pisos;
        this.ciudades = ciudades;
        this.habitaciones = habitaciones;
        this.contratos = contratos;
        this.usuarios = usuarios;
        this.actividad = actividad;
    }

    @Transactional(readOnly = true)
    public List<PisoResponse> listar(UsuarioAutenticado actor) {
        List<Piso> lista = actor.esAdmin()
                ? pisos.findAllByOrderByDireccionAsc()
                : pisos.findByPropietarioIdOrderByDireccionAsc(actor.id());
        return aRespuestas(lista);
    }

    @Transactional(readOnly = true)
    public PisoResponse obtener(Integer id, UsuarioAutenticado actor) {
        return aRespuestas(List.of(cargarPropio(id, actor))).getFirst();
    }

    @Transactional
    public PisoResponse crear(PisoRequest req, UsuarioAutenticado actor) {
        Piso p = new Piso();
        p.setPropietario(usuarios.getReferenceById(actor.id()));
        aplicar(p, req);
        pisos.save(p);
        actividad.registrar(actor.id(), "CREAR_PISO", p.getDireccion());
        return aRespuestas(List.of(p)).getFirst();
    }

    @Transactional
    public PisoResponse actualizar(Integer id, PisoRequest req, UsuarioAutenticado actor) {
        Piso p = cargarPropio(id, actor);
        aplicar(p, req);
        actividad.registrar(actor.id(), "EDITAR_PISO", p.getDireccion());
        return aRespuestas(List.of(p)).getFirst();
    }

    @Transactional
    public void borrar(Integer id, UsuarioAutenticado actor) {
        Piso p = cargarPropio(id, actor);
        if (habitaciones.existsByPisoId(id)) {
            throw ApiException.conflicto("PISO_CON_HABITACIONES",
                    "No se puede borrar un piso con habitaciones; bórralas antes");
        }
        pisos.delete(p);
        actividad.registrar(actor.id(), "BORRAR_PISO", p.getDireccion());
    }

    /** 404 tanto si no existe como si es de otro propietario: no se revela qué ids existen. */
    private Piso cargarPropio(Integer id, UsuarioAutenticado actor) {
        Piso p = pisos.findWithDetallesById(id).orElseThrow(() -> ApiException.noEncontrado("Piso"));
        if (!actor.esAdmin() && !p.getPropietario().getId().equals(actor.id())) {
            throw ApiException.noEncontrado("Piso");
        }
        return p;
    }

    private void aplicar(Piso p, PisoRequest req) {
        p.setDireccion(req.direccion().trim());
        p.setNumeroHabitaciones(req.numeroHabitaciones());
        p.setCiudad(ciudades.findById(req.idCiudad())
                .orElseThrow(() -> ApiException.badRequest("CIUDAD_NO_EXISTE", "No existe la ciudad " + req.idCiudad())));
        if (req.datosFinancieros() != null) {
            DatosPiso d = p.getDatosFinancieros() != null ? p.getDatosFinancieros() : new DatosPiso();
            copiarDatos(req.datosFinancieros(), d);
            p.setDatosFinancieros(d);
        }
    }

    /** Mismas reglas que el guardado del escritorio (AnalisisPisosController). */
    private static void copiarDatos(DatosFinancierosDto src, DatosPiso d) {
        d.setPrecioCompra(nz(src.precioCompra()));
        d.setItpPagado(nz(src.itpPagado()));
        d.setGastosNotaria(nz(src.gastosNotaria()));
        d.setGastosRegistro(nz(src.gastosRegistro()));
        d.setCosteReforma(nz(src.costeReforma()));
        d.setCosteMobiliario(nz(src.costeMobiliario()));
        d.setOtrosGastosCompra(nz(src.otrosGastosCompra()));
        d.setTieneHipoteca(src.tieneHipoteca());
        BigDecimal importe = CalculadoraFinancieraPiso.importeHipotecaEfectivo(src.tieneHipoteca(), nz(src.importeHipoteca()));
        d.setImporteHipoteca(importe);
        d.setTipoInteres(nz(src.tipoInteres()));
        d.setPlazoAnos(src.plazoAnos() != null ? src.plazoAnos() : 0);
        d.setCuotaMensualHipoteca(CalculadoraFinancieraPiso.cuotaMensual(importe, d.getTipoInteres(), d.getPlazoAnos()));
        d.setGastoIbiAnual(nz(src.gastoIbiAnual()));
        d.setGastoComunidadMensual(nz(src.gastoComunidadMensual()));
        d.setGastoSeguroAnual(nz(src.gastoSeguroAnual()));
        d.setGastoMantenimientoAnual(nz(src.gastoMantenimientoAnual()));
        d.setValorMercadoActual(nz(src.valorMercadoActual()));
        d.setFechaCompra(src.fechaCompra());
        d.setNotas(src.notas());
    }

    /** Ocupación e ingresos de todos los pisos en dos consultas, no dos por piso. */
    private List<PisoResponse> aRespuestas(List<Piso> lista) {
        if (lista.isEmpty()) return List.of();
        List<Integer> ids = lista.stream().map(Piso::getId).toList();

        Map<Integer, Map<EstadoHabitacion, Long>> ocupacion = new HashMap<>();
        for (Object[] fila : habitaciones.contarPorPisoYEstado(ids)) {
            ocupacion.computeIfAbsent((Integer) fila[0], k -> new EnumMap<>(EstadoHabitacion.class))
                    .put((EstadoHabitacion) fila[1], (Long) fila[2]);
        }
        Map<Integer, BigDecimal> ingresos = new HashMap<>();
        for (Object[] fila : contratos.ingresosMensualesActivos(ids, LocalDate.now())) {
            ingresos.put((Integer) fila[0], (BigDecimal) fila[1]);
        }

        return lista.stream().map(p -> {
            Map<EstadoHabitacion, Long> occ = ocupacion.getOrDefault(p.getId(), Map.of());
            long alquiladas = occ.getOrDefault(EstadoHabitacion.alquilada, 0L);
            long disponibles = occ.getOrDefault(EstadoHabitacion.disponible, 0L);
            long mantenimiento = occ.getOrDefault(EstadoHabitacion.mantenimiento, 0L);
            BigDecimal ingresosMes = ingresos.getOrDefault(p.getId(), BigDecimal.ZERO);
            DatosPiso d = p.getDatosFinancieros();
            return new PisoResponse(
                    p.getId(), p.getDireccion(),
                    new CiudadResponse(p.getCiudad().getId(), p.getCiudad().getNombre()),
                    p.getNumeroHabitaciones(),
                    p.getPropietario().getId(),
                    new PisoResponse.Ocupacion(alquiladas + disponibles + mantenimiento, alquiladas, disponibles, mantenimiento),
                    ingresosMes,
                    d != null ? aDto(d) : null,
                    d != null ? metricas(d, ingresosMes) : null);
        }).toList();
    }

    static PisoResponse.Metricas metricas(DatosPiso d, BigDecimal ingresosMes) {
        var entrada = new CalculadoraFinancieraPiso.Entrada(
                new CalculadoraFinancieraPiso.DatosAdquisicion(
                        nz(d.getPrecioCompra()), nz(d.getItpPagado()), nz(d.getGastosNotaria()),
                        nz(d.getGastosRegistro()), nz(d.getCosteReforma()), nz(d.getCosteMobiliario()),
                        nz(d.getOtrosGastosCompra())),
                new CalculadoraFinancieraPiso.DatosHipoteca(
                        d.isTieneHipoteca(), nz(d.getImporteHipoteca()), nz(d.getTipoInteres()),
                        d.getPlazoAnos() != null ? d.getPlazoAnos() : 0),
                new CalculadoraFinancieraPiso.DatosGastos(
                        nz(d.getGastoIbiAnual()), nz(d.getGastoComunidadMensual()),
                        nz(d.getGastoSeguroAnual()), nz(d.getGastoMantenimientoAnual())),
                nz(d.getValorMercadoActual()),
                ingresosMes);
        var r = CalculadoraFinancieraPiso.calcular(entrada);
        return new PisoResponse.Metricas(r.inversionTotal(), r.cuotaMensualHipoteca(), r.totalGastosAnuales(),
                r.rentabilidadBrutaPct(), r.rentabilidadNetaPct(), r.calificacion(), r.cashFlowMensual(),
                r.cashOnCashPct(), r.capitalPropio(), r.plusvaliaLatente(), r.perAnios());
    }

    private static DatosFinancierosDto aDto(DatosPiso d) {
        return new DatosFinancierosDto(d.getPrecioCompra(), d.getItpPagado(), d.getGastosNotaria(),
                d.getGastosRegistro(), d.getCosteReforma(), d.getCosteMobiliario(), d.getOtrosGastosCompra(),
                d.isTieneHipoteca(), d.getImporteHipoteca(), d.getTipoInteres(), d.getPlazoAnos(),
                d.getCuotaMensualHipoteca(), d.getGastoIbiAnual(), d.getGastoComunidadMensual(),
                d.getGastoSeguroAnual(), d.getGastoMantenimientoAnual(), d.getValorMercadoActual(),
                d.getFechaCompra(), d.getNotas());
    }

    private static BigDecimal nz(BigDecimal v) {
        return v != null ? v : BigDecimal.ZERO;
    }
}
