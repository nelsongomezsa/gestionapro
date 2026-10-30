package com.gestionap.api.service;

import com.gestionap.api.domain.*;
import com.gestionap.api.repository.*;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.NotificacionResponse;
import org.springframework.data.domain.Limit;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Avisos de NotificacionDAO del escritorio: contrato que vence en 30 días, pago pendiente del
 * mes, incidencia sin resolver más de 7 días y habitación en mantenimiento más de 30 días.
 * Se generan al consultar (como al abrir la campana en el escritorio), solo con lo del
 * propietario, y no se repite un aviso que siga sin leer.
 */
@Service
public class NotificacionService {

    private static final int MAX_LISTA = 100;
    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("d 'de' MMMM", Textos.ES);

    private final NotificacionRepository notificaciones;
    private final ContratoRepository contratos;
    private final PagoRepository pagos;
    private final IncidenciaRepository incidencias;
    private final HabitacionRepository habitaciones;

    public NotificacionService(NotificacionRepository notificaciones, ContratoRepository contratos, PagoRepository pagos,
                               IncidenciaRepository incidencias, HabitacionRepository habitaciones) {
        this.notificaciones = notificaciones;
        this.contratos = contratos;
        this.pagos = pagos;
        this.incidencias = incidencias;
        this.habitaciones = habitaciones;
    }

    @Transactional
    public List<NotificacionResponse> listar(boolean soloNoLeidas, UsuarioAutenticado actor) {
        generar(actor);
        var lista = soloNoLeidas
                ? notificaciones.findByIdUsuarioAndLeidaFalseOrderByFechaDescIdDesc(actor.id(), Limit.of(MAX_LISTA))
                : notificaciones.findByIdUsuarioOrderByFechaDescIdDesc(actor.id(), Limit.of(MAX_LISTA));
        return lista.stream().map(NotificacionResponse::de).toList();
    }

    @Transactional
    public long noLeidas(UsuarioAutenticado actor) {
        generar(actor);
        return notificaciones.countByIdUsuarioAndLeidaFalse(actor.id());
    }

    @Transactional
    public NotificacionResponse marcarLeida(Integer id, UsuarioAutenticado actor) {
        Notificacion n = notificaciones.findByIdAndIdUsuario(id, actor.id())
                .orElseThrow(() -> ApiException.noEncontrado("Notificación"));
        n.setLeida(true);
        return NotificacionResponse.de(n);
    }

    @Transactional
    public int marcarTodasLeidas(UsuarioAutenticado actor) {
        return notificaciones.marcarTodasLeidas(actor.id());
    }

    /** Solo para quien gestiona pisos; un inquilino no recibe estos avisos. */
    void generar(UsuarioAutenticado actor) {
        if (actor.rol() == Rol.INQUILINO) return;
        Integer prop = actor.esAdmin() ? null : actor.id();
        LocalDate hoy = LocalDate.now();
        LocalDateTime inicioHoy = hoy.atStartOfDay();
        List<Contrato> activos = contratos.buscar(prop, null, null).stream().filter(c -> c.estaActivoEn(hoy)).toList();

        for (Contrato c : activos) {
            if (!c.getFechaFin().isAfter(hoy.plusDays(30))) {
                crearSiNoExiste(actor.id(), "contrato_vence_" + c.getId(), "contrato_vence", "Contrato próximo a vencer",
                        "Contrato de " + c.getInquilino().getNombreCompleto() + " vence el " + c.getFechaFin().format(FECHA), inicioHoy);
            }
        }

        Set<Integer> conPagoEsteMes = pagos.buscar(prop, null, hoy.withDayOfMonth(1), hoy.withDayOfMonth(hoy.lengthOfMonth()))
                .stream().map(p -> p.getContrato().getId()).collect(Collectors.toSet());
        String mes = hoy.getYear() + "_" + hoy.getMonthValue();
        for (Contrato c : activos) {
            if (!conPagoEsteMes.contains(c.getId())) {
                crearSiNoExiste(actor.id(), "pago_pendiente_" + c.getId() + "_" + mes, "pago_pendiente", "Pago pendiente este mes",
                        c.getInquilino().getNombreCompleto() + " no tiene pago registrado este mes", inicioHoy);
            }
        }

        for (Incidencia i : incidencias.buscar(prop, null, null, Set.of(EstadoIncidencia.pendiente, EstadoIncidencia.en_proceso))) {
            if (!i.getFecha().isAfter(hoy.minusDays(7))) {
                crearSiNoExiste(actor.id(), "incidencia_antigua_" + i.getId(), "incidencia_antigua",
                        "Incidencia sin resolver > 7 días",
                        recortar(i.getDescripcion(), 120) + " (Hab. " + i.getHabitacion().getNumero() + ")", inicioHoy);
            }
        }

        LocalDate hace30 = hoy.minusDays(30);
        Set<Integer> conContratoReciente = contratos.buscar(prop, null, null).stream()
                .filter(c -> !c.getFechaFin().isBefore(hace30)).map(c -> c.getHabitacion().getId()).collect(Collectors.toSet());
        for (Habitacion h : habitaciones.buscar(prop, null, EstadoHabitacion.mantenimiento)) {
            if (!conContratoReciente.contains(h.getId())) {
                crearSiNoExiste(actor.id(), "mantenimiento_largo_" + h.getId(), "mantenimiento_largo",
                        "Habitación en mantenimiento > 30 días",
                        "Hab. " + h.getNumero() + " — " + h.getPiso().getDireccion(), inicioHoy);
            }
        }
    }

    private void crearSiNoExiste(Integer idUsuario, String referencia, String tipo, String titulo, String descripcion,
                                 LocalDateTime inicioHoy) {
        if (notificaciones.existeVigente(idUsuario, referencia, inicioHoy)) return;
        Notificacion n = new Notificacion();
        n.setIdUsuario(idUsuario);
        n.setReferencia(referencia);
        n.setTipo(tipo);
        n.setTitulo(titulo);
        n.setDescripcion(descripcion);
        n.setFecha(LocalDateTime.now());
        notificaciones.save(n);
    }

    private static String recortar(String s, int max) {
        return s.length() > max ? s.substring(0, max - 1) + "…" : s;
    }
}
