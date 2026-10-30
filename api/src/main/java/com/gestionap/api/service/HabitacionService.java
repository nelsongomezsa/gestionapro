package com.gestionap.api.service;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.EstadoHabitacion;
import com.gestionap.api.domain.Habitacion;
import com.gestionap.api.domain.Piso;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.HabitacionRepository;
import com.gestionap.api.repository.IncidenciaRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.HabitacionRequest;
import com.gestionap.api.web.dto.HabitacionResponse;
import com.gestionap.api.web.dto.PisoBreve;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Habitaciones (HabitacionesController + HabitacionDAO del escritorio), filtradas por propietario. */
@Service
public class HabitacionService {

    private final HabitacionRepository habitaciones;
    private final ContratoRepository contratos;
    private final IncidenciaRepository incidencias;
    private final ControlAcceso acceso;
    private final ActividadService actividad;

    public HabitacionService(HabitacionRepository habitaciones, ContratoRepository contratos,
                             IncidenciaRepository incidencias, ControlAcceso acceso, ActividadService actividad) {
        this.habitaciones = habitaciones;
        this.contratos = contratos;
        this.incidencias = incidencias;
        this.acceso = acceso;
        this.actividad = actividad;
    }

    /** Lista con filtros opcionales: piso, estado y texto (número, dirección, ciudad o inquilino). */
    @Transactional(readOnly = true)
    public List<HabitacionResponse> listar(Integer idPiso, EstadoHabitacion estado, String texto, UsuarioAutenticado actor) {
        if (idPiso != null) acceso.pisoVisible(idPiso, actor);
        List<HabitacionResponse> lista = aRespuestas(habitaciones.buscar(acceso.filtroPropietario(actor), idPiso, estado));
        if (texto == null || texto.isBlank()) return lista;
        String t = texto.trim().toLowerCase(Textos.ES);
        return lista.stream().filter(h -> String.valueOf(h.numero()).equals(t)
                || h.piso().direccion().toLowerCase(Textos.ES).contains(t)
                || h.piso().ciudad().toLowerCase(Textos.ES).contains(t)
                || (h.inquilinoActual() != null && h.inquilinoActual().nombre().toLowerCase(Textos.ES).contains(t)))
                .toList();
    }

    @Transactional(readOnly = true)
    public HabitacionResponse obtener(Integer id, UsuarioAutenticado actor) {
        return aRespuestas(List.of(cargarVisible(id, actor))).getFirst();
    }

    @Transactional
    public HabitacionResponse crear(HabitacionRequest req, UsuarioAutenticado actor) {
        Piso piso = acceso.pisoVisible(req.idPiso(), actor);
        exigirNumeroLibre(piso.getId(), req.numero(), null);
        Habitacion h = new Habitacion();
        h.setPiso(piso);
        h.setNumero(req.numero());
        h.setPrecio(req.precio());
        h.setEstado(req.estado() != null ? req.estado() : EstadoHabitacion.disponible);
        habitaciones.save(h);
        actividad.registrar(actor.id(), "CREAR_HABITACION", "Hab. " + h.getNumero() + " · " + piso.getDireccion());
        return aRespuestas(List.of(h)).getFirst();
    }

    @Transactional
    public HabitacionResponse actualizar(Integer id, HabitacionRequest req, UsuarioAutenticado actor) {
        Habitacion h = cargarVisible(id, actor);
        Piso piso = acceso.pisoVisible(req.idPiso(), actor);
        exigirNumeroLibre(piso.getId(), req.numero(), id);
        if (req.estado() != null) exigirCambioDeEstadoPermitido(h, req.estado());
        h.setPiso(piso);
        h.setNumero(req.numero());
        h.setPrecio(req.precio());
        if (req.estado() != null) h.setEstado(req.estado());
        actividad.registrar(actor.id(), "EDITAR_HABITACION", "Hab. " + h.getNumero() + " · " + piso.getDireccion());
        return aRespuestas(List.of(h)).getFirst();
    }

    @Transactional
    public HabitacionResponse cambiarEstado(Integer id, EstadoHabitacion estado, UsuarioAutenticado actor) {
        Habitacion h = cargarVisible(id, actor);
        exigirCambioDeEstadoPermitido(h, estado);
        h.setEstado(estado);
        actividad.registrar(actor.id(), "CAMBIAR_ESTADO_HABITACION",
                "Hab. " + h.getNumero() + " · " + h.getPiso().getDireccion() + " → " + estado);
        return aRespuestas(List.of(h)).getFirst();
    }

    @Transactional
    public void borrar(Integer id, UsuarioAutenticado actor) {
        Habitacion h = cargarVisible(id, actor);
        if (contratos.existsByHabitacionId(id) || incidencias.existsByHabitacionId(id)) {
            throw ApiException.conflicto("HABITACION_CON_HISTORIAL",
                    "No se puede borrar una habitación con contratos o incidencias registrados");
        }
        habitaciones.delete(h);
        actividad.registrar(actor.id(), "BORRAR_HABITACION", "Hab. " + h.getNumero() + " · " + h.getPiso().getDireccion());
    }

    /**
     * Salvaguarda que el escritorio no tiene: una habitación con contrato activo no puede
     * dejar de estar "alquilada" (se finaliza antes el contrato, que la libera).
     */
    private void exigirCambioDeEstadoPermitido(Habitacion h, EstadoHabitacion nuevo) {
        if (h.getEstado() == EstadoHabitacion.alquilada && nuevo != EstadoHabitacion.alquilada
                && contratos.habitacionTieneContratoActivo(h.getId(), LocalDate.now())) {
            throw ApiException.conflicto("HABITACION_CON_CONTRATO_ACTIVO",
                    "La habitación tiene un contrato activo: finalízalo antes de cambiar su estado");
        }
    }

    private void exigirNumeroLibre(Integer idPiso, int numero, Integer excluirId) {
        if (habitaciones.existeNumeroEnPiso(idPiso, numero, excluirId)) {
            throw ApiException.conflicto("NUMERO_HABITACION_DUPLICADO",
                    "Ya existe la habitación " + numero + " en este piso");
        }
    }

    private Habitacion cargarVisible(Integer id, UsuarioAutenticado actor) {
        Habitacion h = habitaciones.findConPisoById(id).orElseThrow(() -> ApiException.noEncontrado("Habitación"));
        if (!acceso.puedeVerPiso(h.getPiso(), actor)) throw ApiException.noEncontrado("Habitación");
        return h;
    }

    /** Inquilino actual y días alquilada, como las columnas del escritorio, en una consulta. */
    private List<HabitacionResponse> aRespuestas(List<Habitacion> lista) {
        if (lista.isEmpty()) return List.of();
        LocalDate hoy = LocalDate.now();
        Map<Integer, Contrato> activos = contratos.activosDeHabitaciones(lista.stream().map(Habitacion::getId).toList(), hoy)
                .stream().collect(Collectors.toMap(c -> c.getHabitacion().getId(), Function.identity(), (a, b) -> a));
        return lista.stream().map(h -> {
            Contrato c = activos.get(h.getId());
            return new HabitacionResponse(
                    h.getId(), h.getNumero(), h.getPrecio(), h.getEstado(), PisoBreve.de(h.getPiso()),
                    c == null ? null : new HabitacionResponse.InquilinoActual(c.getInquilino().getId(), c.getInquilino().getNombreCompleto()),
                    c == null ? null : c.getId(),
                    c == null ? null : ChronoUnit.DAYS.between(c.getFechaInicio(), hoy));
        }).toList();
    }
}
