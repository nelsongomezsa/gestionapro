package com.gestionap.api.service;

import com.gestionap.api.domain.*;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.HabitacionRepository;
import com.gestionap.api.repository.IncidenciaRepository;
import com.gestionap.api.repository.InquilinoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.IncidenciaDtos.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.EnumSet;
import java.util.List;

/**
 * Incidencias (IncidenciasController + IncidenciaDAO del escritorio). Un propietario gestiona
 * las de sus pisos; un inquilino puede ver y comunicar las de su habitación.
 */
@Service
public class IncidenciaService {

    private final IncidenciaRepository incidencias;
    private final HabitacionRepository habitaciones;
    private final InquilinoRepository inquilinos;
    private final ContratoRepository contratos;
    private final ControlAcceso acceso;
    private final ActividadService actividad;

    public IncidenciaService(IncidenciaRepository incidencias, HabitacionRepository habitaciones,
                             InquilinoRepository inquilinos, ContratoRepository contratos, ControlAcceso acceso,
                             ActividadService actividad) {
        this.incidencias = incidencias;
        this.habitaciones = habitaciones;
        this.inquilinos = inquilinos;
        this.contratos = contratos;
        this.acceso = acceso;
        this.actividad = actividad;
    }

    @Transactional(readOnly = true)
    public List<IncidenciaResponse> listar(EstadoIncidencia estado, Integer idPiso, UsuarioAutenticado actor) {
        var alcance = acceso.alcance(actor);
        LocalDate hoy = LocalDate.now();
        return incidencias.buscar(alcance.idPropietario(), alcance.idInquilino(), idPiso,
                        estado == null ? EnumSet.allOf(EstadoIncidencia.class) : EnumSet.of(estado))
                .stream().map(i -> IncidenciaResponse.de(i, hoy)).toList();
    }

    @Transactional(readOnly = true)
    public IncidenciaResponse obtener(Integer id, UsuarioAutenticado actor) {
        return IncidenciaResponse.de(cargarVisible(id, actor), LocalDate.now());
    }

    @Transactional
    public IncidenciaResponse crear(IncidenciaRequest req, UsuarioAutenticado actor) {
        LocalDate hoy = LocalDate.now();
        Habitacion h;
        Inquilino inq;
        if (actor.rol() == Rol.INQUILINO) {
            Integer idInq = acceso.alcance(actor).idInquilino();
            Contrato c = contratos.buscar(null, idInq, null).stream().filter(x -> x.estaActivoEn(hoy)).findFirst()
                    .orElseThrow(() -> ApiException.conflicto("SIN_CONTRATO_ACTIVO",
                            "Necesitas un contrato activo para comunicar una incidencia"));
            h = c.getHabitacion();
            inq = c.getInquilino();
        } else {
            if (req.idHabitacion() == null) throw ApiException.badRequest("HABITACION_REQUERIDA", "Indica la habitación");
            h = habitaciones.findConPisoById(req.idHabitacion())
                    .filter(x -> acceso.puedeVerPiso(x.getPiso(), actor))
                    .orElseThrow(() -> ApiException.noEncontrado("Habitación"));
            if (req.idInquilino() != null) {
                inq = inquilinos.findById(req.idInquilino())
                        .filter(x -> actor.esAdmin() || inquilinos.esVisiblePara(x.getId(), actor.id()))
                        .orElseThrow(() -> ApiException.noEncontrado("Inquilino"));
            } else {
                // La tabla exige inquilino: se usa el del contrato activo de la habitación.
                inq = contratos.activosDeHabitaciones(List.of(h.getId()), hoy).stream().findFirst()
                        .map(Contrato::getInquilino)
                        .orElseThrow(() -> ApiException.badRequest("INQUILINO_REQUERIDO",
                                "La habitación no tiene contrato activo: indica el inquilino"));
            }
        }
        Incidencia i = new Incidencia();
        i.setHabitacion(h);
        i.setInquilino(inq);
        i.setDescripcion(req.descripcion().trim());
        i.setFecha(req.fecha() != null ? req.fecha() : hoy);
        i.setCosteReparacion(actor.rol() == Rol.INQUILINO || req.costeReparacion() == null ? BigDecimal.ZERO : req.costeReparacion());
        incidencias.save(i);
        actividad.registrar(actor.id(), "CREAR_INCIDENCIA", "Hab. " + h.getNumero() + " · " + i.getDescripcion());
        return IncidenciaResponse.de(i, hoy);
    }

    /** Sin estado, avanza un paso: pendiente → en proceso → resuelta (409 si ya está resuelta). */
    @Transactional
    public IncidenciaResponse cambiarEstado(Integer id, EstadoIncidencia estado, UsuarioAutenticado actor) {
        Incidencia i = cargarGestionable(id, actor);
        EstadoIncidencia nuevo = estado != null ? estado : i.getEstado().siguiente();
        if (nuevo == null) throw ApiException.conflicto("INCIDENCIA_RESUELTA", "La incidencia ya está resuelta");
        i.setEstado(nuevo);
        actividad.registrar(actor.id(), "CAMBIAR_ESTADO_INCIDENCIA", "#" + id + " → " + nuevo);
        return IncidenciaResponse.de(i, LocalDate.now());
    }

    @Transactional
    public IncidenciaResponse actualizar(Integer id, ActualizarIncidenciaRequest req, UsuarioAutenticado actor) {
        Incidencia i = cargarGestionable(id, actor);
        if (req.descripcion() != null) i.setDescripcion(req.descripcion().trim());
        if (req.costeReparacion() != null) i.setCosteReparacion(req.costeReparacion());
        actividad.registrar(actor.id(), "EDITAR_INCIDENCIA", "#" + id);
        return IncidenciaResponse.de(i, LocalDate.now());
    }

    @Transactional
    public void borrar(Integer id, UsuarioAutenticado actor) {
        Incidencia i = cargarGestionable(id, actor);
        incidencias.delete(i);
        actividad.registrar(actor.id(), "BORRAR_INCIDENCIA", "#" + id + " · " + i.getDescripcion());
    }

    Incidencia cargarVisible(Integer id, UsuarioAutenticado actor) {
        Incidencia i = incidencias.findById(id).orElseThrow(() -> ApiException.noEncontrado("Incidencia"));
        boolean visible = switch (actor.rol()) {
            case ADMIN -> true;
            case PROPIETARIO -> i.getHabitacion().getPiso().getPropietario().getId().equals(actor.id());
            case INQUILINO -> i.getInquilino().getUsuario() != null && i.getInquilino().getUsuario().getId().equals(actor.id());
        };
        if (!visible) throw ApiException.noEncontrado("Incidencia");
        return i;
    }

    /** Cambiar, editar o borrar: solo el admin o el propietario del piso. */
    private Incidencia cargarGestionable(Integer id, UsuarioAutenticado actor) {
        Incidencia i = cargarVisible(id, actor);
        if (actor.rol() == Rol.INQUILINO) throw new org.springframework.security.access.AccessDeniedException("Solo lectura");
        return i;
    }
}
