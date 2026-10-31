package com.gestionap.api.service;

import com.gestionap.api.domain.*;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.IncidenciaRepository;
import com.gestionap.api.repository.MensajeRepository;
import com.gestionap.api.repository.UsuarioRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.MensajeDtos.Conversacion;
import com.gestionap.api.web.dto.MensajeDtos.MensajeRequest;
import com.gestionap.api.web.dto.MensajeDtos.MensajeResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Mensajería propietario ↔ inquilino, siempre dentro de un contrato (y opcionalmente de una
 * incidencia suya). Cada uno solo ve las conversaciones de sus contratos; el inquilino necesita
 * cuenta en la app. Cada mensaje nuevo avisa a la otra parte en Notificaciones (un aviso sin
 * leer por conversación, no uno por mensaje).
 */
@Service
public class MensajeService {

    private final MensajeRepository mensajes;
    private final ContratoService contratos;
    private final ContratoRepository contratosRepo;
    private final IncidenciaRepository incidencias;
    private final UsuarioRepository usuarios;
    private final NotificacionService notificaciones;
    private final ControlAcceso acceso;

    public MensajeService(MensajeRepository mensajes, ContratoService contratos, ContratoRepository contratosRepo,
                          IncidenciaRepository incidencias, UsuarioRepository usuarios,
                          NotificacionService notificaciones, ControlAcceso acceso) {
        this.mensajes = mensajes;
        this.contratos = contratos;
        this.contratosRepo = contratosRepo;
        this.incidencias = incidencias;
        this.usuarios = usuarios;
        this.notificaciones = notificaciones;
        this.acceso = acceso;
    }

    /** El hilo; al leerlo se marcan leídos los mensajes de la otra parte. */
    @Transactional
    public List<MensajeResponse> hilo(Integer idContrato, Integer idIncidencia, UsuarioAutenticado actor) {
        Contrato c = contratos.cargarVisible(idContrato, actor);
        validarIncidencia(c, idIncidencia);
        mensajes.marcarLeidos(idContrato, idIncidencia, actor.id());
        return mensajes.hilo(idContrato, idIncidencia).stream().map(m -> MensajeResponse.de(m, actor.id())).toList();
    }

    @Transactional
    public MensajeResponse enviar(Integer idContrato, MensajeRequest req, UsuarioAutenticado actor) {
        Contrato c = contratos.cargarVisible(idContrato, actor);
        validarIncidencia(c, req.idIncidencia());
        Usuario destinatario = destinatario(c, actor);
        Mensaje m = new Mensaje();
        m.setContrato(c);
        m.setIdIncidencia(req.idIncidencia());
        m.setAutor(usuarios.getReferenceById(actor.id()));
        m.setTexto(req.texto().trim());
        m.setFecha(LocalDateTime.now());
        mensajes.save(m);
        String referencia = "mensaje_" + c.getId() + (req.idIncidencia() != null ? "_i" + req.idIncidencia() : "");
        notificaciones.avisarSinRepetirMientrasNoLeido(destinatario.getId(), referencia, "mensaje",
                "Mensaje de " + actor.nombre(), recortar(m.getTexto(), 120));
        return MensajeResponse.de(m, actor.id());
    }

    /** Contrato de una incidencia: el del inquilino que la comunicó en esa habitación (el más reciente). */
    @Transactional(readOnly = true)
    public Integer contratoDeIncidencia(Integer idIncidencia, UsuarioAutenticado actor) {
        Incidencia i = incidencias.findById(idIncidencia).orElseThrow(() -> ApiException.noEncontrado("Incidencia"));
        var alcance = acceso.alcance(actor);
        return contratosRepo.buscar(alcance.idPropietario(), alcance.idInquilino(), null).stream()
                .filter(c -> c.getHabitacion().getId().equals(i.getHabitacion().getId())
                        && c.getInquilino().getId().equals(i.getInquilino().getId()))
                .max(java.util.Comparator.comparing(Contrato::getFechaInicio))
                .map(Contrato::getId)
                .orElseThrow(() -> ApiException.noEncontrado("Incidencia"));
    }

    /** Bandeja: una fila por conversación (general o de incidencia) de los contratos visibles. */
    @Transactional(readOnly = true)
    public List<Conversacion> conversaciones(UsuarioAutenticado actor) {
        var alcance = acceso.alcance(actor);
        Map<Integer, Contrato> visibles = new LinkedHashMap<>();
        contratosRepo.buscar(alcance.idPropietario(), alcance.idInquilino(), null).forEach(c -> visibles.put(c.getId(), c));
        if (visibles.isEmpty()) return List.of();
        Map<String, List<Mensaje>> porHilo = new LinkedHashMap<>();
        for (Mensaje m : mensajes.deContratos(visibles.keySet())) {
            porHilo.computeIfAbsent(m.getContrato().getId() + "/" + m.getIdIncidencia(), k -> new ArrayList<>()).add(m);
        }
        List<Conversacion> lista = new ArrayList<>();
        for (List<Mensaje> hilo : porHilo.values()) {
            Mensaje ultimo = hilo.get(0);
            Contrato c = visibles.get(ultimo.getContrato().getId());
            boolean soyInquilino = actor.rol() == Rol.INQUILINO;
            String con = soyInquilino ? c.getHabitacion().getPiso().getPropietario().getNombre() : c.getInquilino().getNombreCompleto();
            String asunto = ultimo.getIdIncidencia() != null
                    ? "Incidencia: " + incidencias.findById(ultimo.getIdIncidencia()).map(Incidencia::getDescripcion).orElse("")
                    : "Habitación " + c.getHabitacion().getNumero() + " · " + c.getHabitacion().getPiso().getDireccion();
            long sinLeer = hilo.stream().filter(m -> !m.isLeido() && !esDe(m, actor)).count();
            lista.add(new Conversacion(c.getId(), ultimo.getIdIncidencia(), con, recortar(asunto, 80), recortar(ultimo.getTexto(), 120),
                    Textos.conZona(ultimo.getFecha()), esDe(ultimo, actor), sinLeer));
        }
        return lista;
    }

    /** El otro lado: el inquilino (si tiene cuenta) o el propietario del piso. */
    private Usuario destinatario(Contrato c, UsuarioAutenticado actor) {
        if (actor.rol() == Rol.INQUILINO) return c.getHabitacion().getPiso().getPropietario();
        Usuario cuenta = c.getInquilino().getUsuario();
        if (cuenta == null) {
            throw ApiException.conflicto("INQUILINO_SIN_CUENTA",
                    "El inquilino aún no tiene cuenta en la app: invítale desde su ficha para poder escribirle");
        }
        return cuenta;
    }

    private void validarIncidencia(Contrato c, Integer idIncidencia) {
        if (idIncidencia == null) return;
        Incidencia i = incidencias.findById(idIncidencia).orElseThrow(() -> ApiException.noEncontrado("Incidencia"));
        boolean deEsteContrato = i.getHabitacion().getId().equals(c.getHabitacion().getId())
                && i.getInquilino().getId().equals(c.getInquilino().getId());
        if (!deEsteContrato) throw ApiException.badRequest("INCIDENCIA_NO_VALIDA", "La incidencia no es de este contrato");
    }

    private static boolean esDe(Mensaje m, UsuarioAutenticado actor) {
        return m.getAutor() != null && Objects.equals(m.getAutor().getId(), actor.id());
    }

    private static String recortar(String s, int max) {
        return s.length() > max ? s.substring(0, max - 1) + "…" : s;
    }
}
