package com.gestionap.api.service;

import com.gestionap.api.domain.*;
import com.gestionap.api.repository.*;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.NotificacionResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Limit;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Avisos de NotificacionDAO del escritorio: contrato que vence en 30 días, pago pendiente del
 * mes, incidencia sin resolver más de 7 días y habitación en mantenimiento más de 30 días.
 * Se generan al consultar (como al abrir la campana en el escritorio), solo con lo del
 * propietario. Cada aviso se crea una sola vez por referencia (tipo + contrato, incidencia o
 * habitación + periodo, p. ej. "pago_pendiente_12_2026_10").
 *
 * Nuevo en la API (fase 5): "cobro vencido" para quien gestiona, pasado el día límite de pago
 * sin ningún pago del mes, y para el inquilino un recordatorio unos días antes y un aviso si
 * se pasa. El día límite por defecto es el 7: la LAU (art. 17.2) dice que, salvo pacto, la
 * renta se paga "en los siete primeros días del mes".
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
    private final InquilinoRepository inquilinos;
    private final UsuarioRepository usuarios;
    private final PushService push;
    private final int diaLimite;
    private final int diasAviso;

    public NotificacionService(NotificacionRepository notificaciones, ContratoRepository contratos, PagoRepository pagos,
                               IncidenciaRepository incidencias, HabitacionRepository habitaciones,
                               InquilinoRepository inquilinos, UsuarioRepository usuarios, PushService push,
                               @Value("${gestionap.cobros.dia-limite:7}") int diaLimite,
                               @Value("${gestionap.cobros.dias-aviso:3}") int diasAviso) {
        this.notificaciones = notificaciones;
        this.contratos = contratos;
        this.pagos = pagos;
        this.incidencias = incidencias;
        this.habitaciones = habitaciones;
        this.inquilinos = inquilinos;
        this.usuarios = usuarios;
        this.push = push;
        this.diaLimite = diaLimite;
        this.diasAviso = diasAviso;
    }

    /** Día del mes en que vence la renta (el límite si el mes es más corto). */
    public LocalDate vencimiento(YearMonth mes) {
        return mes.atDay(Math.min(diaLimite, mes.lengthOfMonth()));
    }

    /** Para la tarea diaria de push: genera los avisos de un usuario aunque no abra la app. */
    @Transactional
    public void generarPara(Usuario u, LocalDate hoy) {
        generar(new UsuarioAutenticado(u.getId(), u.getEmail(), u.getNombre(), u.getRol()), hoy);
    }

    public int diasAviso() {
        return diasAviso;
    }

    /**
     * Cada aviso una vez: si la base tiene copias de la misma referencia (el escritorio las
     * repetía cada día), se devuelve solo la más reciente, sin leer si alguna lo está.
     */
    @Transactional
    public List<NotificacionResponse> listar(boolean soloNoLeidas, UsuarioAutenticado actor) {
        generar(actor);
        var todas = soloNoLeidas
                ? notificaciones.findByIdUsuarioAndLeidaFalseOrderByFechaDescIdDesc(actor.id(), Limit.of(MAX_LISTA * 4))
                : notificaciones.findByIdUsuarioOrderByFechaDescIdDesc(actor.id(), Limit.of(MAX_LISTA * 4));
        Map<String, Notificacion> porReferencia = new LinkedHashMap<>();
        Set<String> conNoLeida = new HashSet<>();
        for (Notificacion n : todas) {
            String clave = n.getReferencia() != null ? n.getReferencia() : "#" + n.getId();
            if (!n.isLeida()) conNoLeida.add(clave);
            porReferencia.putIfAbsent(clave, n);
        }
        return porReferencia.entrySet().stream().limit(MAX_LISTA).map(e -> {
            var r = NotificacionResponse.de(e.getValue());
            return conNoLeida.contains(e.getKey()) && r.leida() ? r.comoNoLeida() : r;
        }).toList();
    }

    @Transactional
    public long noLeidas(UsuarioAutenticado actor) {
        generar(actor);
        return notificaciones.contarReferenciasNoLeidas(actor.id())
                + notificaciones.countByIdUsuarioAndLeidaFalseAndReferenciaIsNull(actor.id());
    }

    @Transactional
    public NotificacionResponse marcarLeida(Integer id, UsuarioAutenticado actor) {
        Notificacion n = notificaciones.findByIdAndIdUsuario(id, actor.id())
                .orElseThrow(() -> ApiException.noEncontrado("Notificación"));
        n.setLeida(true);
        if (n.getReferencia() != null) notificaciones.marcarLeidasPorReferencia(actor.id(), n.getReferencia());
        return NotificacionResponse.de(n);
    }

    @Transactional
    public int marcarTodasLeidas(UsuarioAutenticado actor) {
        return notificaciones.marcarTodasLeidas(actor.id());
    }

    /** Los del escritorio, solo para quien gestiona pisos; el inquilino recibe los suyos de pago. */
    void generar(UsuarioAutenticado actor) {
        generar(actor, LocalDate.now());
    }

    /** Con la fecha como parámetro para poder probar cada día del mes. */
    void generar(UsuarioAutenticado actor, LocalDate hoy) {
        // De uno en uno por usuario: la lista y el contador se piden a la vez y, sin bloqueo,
        // las dos peticiones creaban el mismo aviso.
        usuarios.bloquear(actor.id());
        if (actor.rol() == Rol.INQUILINO) {
            generarInquilino(actor, hoy);
            return;
        }
        Integer prop = actor.esAdmin() ? null : actor.id();
        List<Contrato> activos = contratos.buscar(prop, null, null).stream().filter(c -> c.estaActivoEn(hoy)).toList();

        for (Contrato c : activos) {
            if (!c.getFechaFin().isAfter(hoy.plusDays(30))) {
                crearUnaVez(actor.id(), "contrato_vence_" + c.getId(), "contrato_vence", "Contrato próximo a vencer",
                        "Contrato de " + c.getInquilino().getNombreCompleto() + " vence el " + c.getFechaFin().format(FECHA));
            }
        }

        Set<Integer> conPagoEsteMes = pagos.buscar(prop, null, hoy.withDayOfMonth(1), hoy.withDayOfMonth(hoy.lengthOfMonth()))
                .stream().map(p -> p.getContrato().getId()).collect(Collectors.toSet());
        String mes = hoy.getYear() + "_" + hoy.getMonthValue();
        LocalDate vence = vencimiento(YearMonth.from(hoy));
        for (Contrato c : activos) {
            // Pasado el día límite, "Cobro vencido" sustituye a "Pago pendiente" (no se avisa dos veces).
            boolean vencido = hoy.isAfter(vence) && !c.getFechaInicio().isAfter(vence);
            if (!conPagoEsteMes.contains(c.getId()) && !vencido) {
                crearUnaVez(actor.id(), "pago_pendiente_" + c.getId() + "_" + mes, "pago_pendiente", "Pago pendiente este mes",
                        c.getInquilino().getNombreCompleto() + " no tiene pago registrado este mes");
            }
        }

        for (Contrato c : activos) {
            // Solo si el contrato ya estaba en vigor el día límite (uno que empieza el 20 no debía pagar el 7).
            if (hoy.isAfter(vence) && !c.getFechaInicio().isAfter(vence) && !conPagoEsteMes.contains(c.getId())) {
                crearUnaVez(actor.id(), "cobro_vencido_" + c.getId() + "_" + mes, "cobro_vencido", "Cobro vencido",
                        c.getInquilino().getNombreCompleto() + " · " + Textos.euros(c.getPrecioMensual())
                                + ": vencía el " + vence.format(FECHA) + " (" + hace(hoy.toEpochDay() - vence.toEpochDay()) + ")");
            }
        }

        for (Incidencia i : incidencias.buscar(prop, null, null, Set.of(EstadoIncidencia.pendiente, EstadoIncidencia.en_proceso))) {
            if (!i.getFecha().isAfter(hoy.minusDays(7))) {
                crearUnaVez(actor.id(), "incidencia_antigua_" + i.getId(), "incidencia_antigua",
                        "Incidencia sin resolver > 7 días",
                        recortar(i.getDescripcion(), 120) + " (Hab. " + i.getHabitacion().getNumero() + ")");
            }
        }

        LocalDate hace30 = hoy.minusDays(30);
        Set<Integer> conContratoReciente = contratos.buscar(prop, null, null).stream()
                .filter(c -> !c.getFechaFin().isBefore(hace30)).map(c -> c.getHabitacion().getId()).collect(Collectors.toSet());
        for (Habitacion h : habitaciones.buscar(prop, null, EstadoHabitacion.mantenimiento)) {
            if (!conContratoReciente.contains(h.getId())) {
                crearUnaVez(actor.id(), "mantenimiento_largo_" + h.getId(), "mantenimiento_largo",
                        "Habitación en mantenimiento > 30 días",
                        "Hab. " + h.getNumero() + " — " + h.getPiso().getDireccion());
            }
        }
    }

    /** Recordatorio antes del día límite y aviso si se pasa, sin ningún pago del mes. */
    private void generarInquilino(UsuarioAutenticado actor, LocalDate hoy) {
        Integer idInquilino = inquilinos.findByUsuarioId(actor.id()).map(Inquilino::getId).orElse(null);
        if (idInquilino == null) return;
        YearMonth mes = YearMonth.from(hoy);
        LocalDate vence = vencimiento(mes);
        String clave = mes.getYear() + "_" + mes.getMonthValue();
        Set<Integer> conPago = pagos.buscar(null, idInquilino, mes.atDay(1), mes.atEndOfMonth()).stream()
                .map(p -> p.getContrato().getId()).collect(Collectors.toSet());
        for (Contrato c : contratos.buscar(null, idInquilino, null)) {
            if (!c.estaActivoEn(hoy) || c.getFechaInicio().isAfter(vence) || conPago.contains(c.getId())) continue;
            String renta = "La renta de " + Textos.mes(mes) + " (" + Textos.euros(c.getPrecioMensual()) + ")";
            if (hoy.isAfter(vence)) {
                crearUnaVez(actor.id(), "pago_atrasado_" + c.getId() + "_" + clave, "pago_atrasado", "Renta pendiente",
                        renta + " vencía el " + vence.format(FECHA) + ". Si ya la has pagado, avisa a tu propietario.");
            } else if (!hoy.isBefore(vence.minusDays(diasAviso))) {
                crearUnaVez(actor.id(), "recordatorio_pago_" + c.getId() + "_" + clave, "recordatorio_pago", "Recuerda pagar la renta",
                        renta + " vence el " + vence.format(FECHA) + ".");
            }
        }
    }

    boolean yaExiste(Integer idUsuario, String referencia) {
        return notificaciones.existsByIdUsuarioAndReferencia(idUsuario, referencia);
    }

    /** Para los mensajes: un aviso sin leer por conversación; leído, el siguiente mensaje avisa de nuevo. */
    public void avisarSinRepetirMientrasNoLeido(Integer idUsuario, String referencia, String tipo, String titulo, String descripcion) {
        // Dos mensajes a la vez no pueden crear dos avisos de la misma conversación.
        usuarios.bloquear(idUsuario);
        if (notificaciones.existsByIdUsuarioAndReferenciaAndLeidaFalse(idUsuario, referencia)) return;
        Notificacion n = new Notificacion();
        n.setIdUsuario(idUsuario);
        n.setReferencia(referencia);
        n.setTipo(tipo);
        n.setTitulo(titulo);
        n.setDescripcion(descripcion);
        n.setFecha(LocalDateTime.now());
        notificaciones.save(n);
        push.enviar(idUsuario, titulo, descripcion);
    }

    /** Avisos que se dan una sola vez por referencia (uno por contrato y mes). */
    void crearUnaVez(Integer idUsuario, String referencia, String tipo, String titulo, String descripcion) {
        if (notificaciones.existsByIdUsuarioAndReferencia(idUsuario, referencia)) return;
        Notificacion n = new Notificacion();
        n.setIdUsuario(idUsuario);
        n.setReferencia(referencia);
        n.setTipo(tipo);
        n.setTitulo(titulo);
        n.setDescripcion(descripcion);
        n.setFecha(LocalDateTime.now());
        notificaciones.save(n);
        push.enviar(idUsuario, titulo, descripcion);
    }

    private static String hace(long dias) {
        return dias == 1 ? "hace 1 día" : "hace " + dias + " días";
    }

    private static String recortar(String s, int max) {
        return s.length() > max ? s.substring(0, max - 1) + "…" : s;
    }
}
