package com.gestionap.api.service;

import com.gestionap.api.domain.*;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.HabitacionRepository;
import com.gestionap.api.repository.InquilinoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.ContratoRequest;
import com.gestionap.api.web.dto.ContratoResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.function.Predicate;

/** Contratos (ContratosController + ContratoDAO del escritorio). */
@Service
public class ContratoService {

    /** Filtro de la lista: los del escritorio (todos, activos, finalizados) más "por vencer". */
    public enum Filtro { TODOS, ACTIVOS, POR_VENCER, FINALIZADOS }

    public record Pdf(String nombreArchivo, byte[] contenido) {}

    private final ContratoRepository contratos;
    private final HabitacionRepository habitaciones;
    private final InquilinoRepository inquilinos;
    private final ContratoPdfGenerator generador;
    private final ControlAcceso acceso;
    private final ActividadService actividad;

    public ContratoService(ContratoRepository contratos, HabitacionRepository habitaciones, InquilinoRepository inquilinos,
                           ContratoPdfGenerator generador, ControlAcceso acceso, ActividadService actividad) {
        this.contratos = contratos;
        this.habitaciones = habitaciones;
        this.inquilinos = inquilinos;
        this.generador = generador;
        this.acceso = acceso;
        this.actividad = actividad;
    }

    @Transactional(readOnly = true)
    public List<ContratoResponse> listar(Filtro filtro, Integer idPiso, Integer idInquilino, UsuarioAutenticado actor) {
        LocalDate hoy = LocalDate.now();
        var alcance = acceso.alcance(actor);
        Integer inquilino = alcance.idInquilino() != null ? alcance.idInquilino() : idInquilino;
        Predicate<Contrato> criterio = switch (filtro == null ? Filtro.TODOS : filtro) {
            case TODOS -> c -> true;
            case ACTIVOS -> c -> c.estaActivoEn(hoy);
            case POR_VENCER -> c -> c.estaActivoEn(hoy)
                    && NivelVencimiento.de(c.getFechaFin(), hoy).compareTo(NivelVencimiento.PROXIMO) <= 0;
            case FINALIZADOS -> c -> c.getFechaFin().isBefore(hoy);
        };
        return contratos.buscar(alcance.idPropietario(), inquilino, idPiso).stream()
                .filter(criterio).map(c -> ContratoResponse.de(c, hoy)).toList();
    }

    @Transactional(readOnly = true)
    public ContratoResponse obtener(Integer id, UsuarioAutenticado actor) {
        return ContratoResponse.de(cargarVisible(id, actor), LocalDate.now());
    }

    /**
     * Nuevo contrato reservando la habitación en la misma transacción, como
     * ContratoDAO.crearConHabitacion del escritorio: si la habitación ya no está disponible
     * (otro usuario la alquiló a la vez), no se crea nada.
     */
    @Transactional
    public ContratoResponse crear(ContratoRequest req, UsuarioAutenticado actor) {
        if (!req.fechaFin().isAfter(req.fechaInicio())) {
            throw ApiException.badRequest("FECHAS_NO_VALIDAS", "La fecha de fin debe ser posterior a la de inicio");
        }
        Habitacion h = habitaciones.findConPisoById(req.idHabitacion())
                .filter(x -> acceso.puedeVerPiso(x.getPiso(), actor))
                .orElseThrow(() -> ApiException.noEncontrado("Habitación"));
        Inquilino i = inquilinos.findById(req.idInquilino())
                .filter(x -> actor.esAdmin() || inquilinos.esVisiblePara(x.getId(), actor.id()))
                .orElseThrow(() -> ApiException.noEncontrado("Inquilino"));

        if (habitaciones.cambiarEstadoSi(h.getId(), EstadoHabitacion.disponible, EstadoHabitacion.alquilada) == 0) {
            throw ApiException.conflicto("HABITACION_NO_DISPONIBLE",
                    "La habitación ya no está disponible (puede que otro usuario la haya alquilado)");
        }
        // Tras el UPDATE masivo se recargan las entidades (el contexto se ha limpiado).
        h = habitaciones.findConPisoById(h.getId()).orElseThrow();
        i = inquilinos.findById(i.getId()).orElseThrow();
        if (i.getPropietario() == null) i.setPropietario(h.getPiso().getPropietario());

        Contrato c = new Contrato();
        c.setHabitacion(h);
        c.setInquilino(i);
        c.setFechaInicio(req.fechaInicio());
        c.setFechaFin(req.fechaFin());
        c.setPrecioMensual(req.precioMensual());
        contratos.save(c);
        actividad.registrar(actor.id(), "CREAR_CONTRATO",
                i.getNombreCompleto() + " · Hab. " + h.getNumero() + " · " + h.getPiso().getDireccion());
        return ContratoResponse.de(c, LocalDate.now());
    }

    /** Finaliza hoy un contrato activo y libera la habitación, en la misma transacción. */
    @Transactional
    public ContratoResponse finalizar(Integer id, UsuarioAutenticado actor) {
        Contrato c = cargarVisible(id, actor);
        LocalDate hoy = LocalDate.now();
        if (!c.estaActivoEn(hoy)) {
            throw ApiException.conflicto("CONTRATO_NO_ACTIVO", "El contrato ya está finalizado o aún no ha empezado");
        }
        c.setFechaFin(hoy);
        contratos.flush();
        habitaciones.cambiarEstadoSi(c.getHabitacion().getId(), EstadoHabitacion.alquilada, EstadoHabitacion.disponible);
        Contrato actualizado = contratos.findConDetallesById(id).orElseThrow();
        actividad.registrar(actor.id(), "FINALIZAR_CONTRATO",
                actualizado.getInquilino().getNombreCompleto() + " · Hab. " + actualizado.getHabitacion().getNumero());
        return ContratoResponse.de(actualizado, hoy);
    }

    /** PDF del contrato: para el ADMIN, el propietario del piso o el inquilino del contrato. */
    @Transactional(readOnly = true)
    public Pdf pdf(Integer idContrato, UsuarioAutenticado actor) {
        Contrato c = cargarVisible(idContrato, actor);
        var piso = c.getHabitacion().getPiso();
        Usuario propietario = piso.getPropietario();
        var datos = new ContratoPdfGenerator.DatosContrato(
                c.getId(),
                propietario.getNombre(),
                propietario.getDni(),
                c.getInquilino().getNombreCompleto(),
                c.getInquilino().getDni(),
                piso.getDireccion(),
                piso.getCiudad().getNombre(),
                c.getHabitacion().getNumero(),
                c.getFechaInicio(),
                c.getFechaFin(),
                c.getPrecioMensual());
        return new Pdf(generador.nombreArchivo(datos), generador.generar(datos));
    }

    Contrato cargarVisible(Integer id, UsuarioAutenticado actor) {
        Contrato c = contratos.findConDetallesById(id).orElseThrow(() -> ApiException.noEncontrado("Contrato"));
        if (!acceso.puedeVerContrato(c, actor)) throw ApiException.noEncontrado("Contrato");
        return c;
    }
}
