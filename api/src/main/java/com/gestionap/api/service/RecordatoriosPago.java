package com.gestionap.api.service;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.PagoRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Recordatorio de pago por email a los inquilinos, unos días antes del límite y sin ningún
 * pago del mes. Una vez por contrato y mes: el envío queda anotado como aviso del propietario
 * ("Recordatorio enviado a…"), que además le sirve para saberlo. Sin email configurado no hace nada.
 */
@Slf4j
@Component
public class RecordatoriosPago {

    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("d 'de' MMMM", Textos.ES);

    private final ContratoRepository contratos;
    private final PagoRepository pagos;
    private final NotificacionService notificaciones;
    private final EmailService email;
    private PushService push;
    private com.gestionap.api.repository.DispositivoRepository dispositivos;
    private com.gestionap.api.repository.UsuarioRepository usuarios;

    public RecordatoriosPago(ContratoRepository contratos, PagoRepository pagos, NotificacionService notificaciones,
                             EmailService email) {
        this.contratos = contratos;
        this.pagos = pagos;
        this.notificaciones = notificaciones;
        this.email = email;
    }

    @org.springframework.beans.factory.annotation.Autowired
    void push(PushService push, com.gestionap.api.repository.DispositivoRepository dispositivos,
              com.gestionap.api.repository.UsuarioRepository usuarios) {
        this.push = push;
        this.dispositivos = dispositivos;
        this.usuarios = usuarios;
    }

    /** Cada día a las 9:00 (hora de Madrid). "-" en gestionap.recordatorios.cron lo desactiva. */
    @Scheduled(cron = "${gestionap.recordatorios.cron:0 0 9 * * *}", zone = "Europe/Madrid")
    @Transactional
    public void enviarDelDia() {
        enviar(LocalDate.now());
        avisosConPush(LocalDate.now());
    }

    /**
     * Con push configurado, genera los avisos del día de quien tiene un iPhone registrado: así le
     * llegan (cobro vencido, recordatorio de pago…) sin tener que abrir la app.
     */
    @Transactional
    public int avisosConPush(LocalDate hoy) {
        if (push == null || !push.configurado()) return 0;
        int usuariosConAvisos = 0;
        for (var u : usuarios.findAll()) {
            if (u.isActivo() && !dispositivos.findByIdUsuario(u.getId()).isEmpty()) {
                notificaciones.generarPara(u, hoy);
                usuariosConAvisos++;
            }
        }
        return usuariosConAvisos;
    }

    /** Devuelve cuántos recordatorios ha enviado (para los tests). */
    @Transactional
    public int enviar(LocalDate hoy) {
        if (!email.estaConfigurado()) return 0;
        YearMonth mes = YearMonth.from(hoy);
        LocalDate vence = notificaciones.vencimiento(mes);
        if (hoy.isAfter(vence) || hoy.isBefore(vence.minusDays(notificaciones.diasAviso()))) return 0;
        Set<Integer> conPago = pagos.buscar(null, null, mes.atDay(1), mes.atEndOfMonth()).stream()
                .map(p -> p.getContrato().getId()).collect(Collectors.toSet());
        int enviados = 0;
        for (Contrato c : contratos.buscar(null, null, null)) {
            var inquilino = c.getInquilino();
            if (!c.estaActivoEn(hoy) || c.getFechaInicio().isAfter(vence) || conPago.contains(c.getId())
                    || inquilino.getEmail() == null || inquilino.getEmail().isBlank()) continue;
            Integer propietario = c.getHabitacion().getPiso().getPropietario().getId();
            String referencia = "recordatorio_enviado_" + c.getId() + "_" + mes.getYear() + "_" + mes.getMonthValue();
            if (notificaciones.yaExiste(propietario, referencia)) continue;
            boolean ok = email.enviar(inquilino.getEmail(), "Recordatorio: renta de " + Textos.mes(mes),
                    "Hola, " + inquilino.getNombre() + ":\n\nTe recordamos que la renta de " + Textos.mes(mes) + " ("
                            + Textos.euros(c.getPrecioMensual()) + ") de la habitación " + c.getHabitacion().getNumero()
                            + " vence el " + vence.format(FECHA) + ". Si ya la has pagado, ignora este mensaje.\n\nGestionAp");
            if (ok) {
                notificaciones.crearUnaVez(propietario, referencia, "recordatorio_enviado", "Recordatorio enviado",
                        inquilino.getNombreCompleto() + " · renta de " + Textos.mes(mes) + " (" + inquilino.getEmail() + ")");
                enviados++;
            }
        }
        if (enviados > 0) log.info("Recordatorios de pago enviados: {}", enviados);
        return enviados;
    }
}
