package com.gestionap.api.web.dto;

import com.gestionap.api.domain.Notificacion;
import io.swagger.v3.oas.annotations.media.Schema;

import com.gestionap.api.service.Textos;

import java.time.OffsetDateTime;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public record NotificacionResponse(
        Integer id,
        String tipo,
        String titulo,
        String descripcion,
        OffsetDateTime fecha,
        boolean leida,
        @Schema(description = "Pantalla a la que lleva al tocarla (RutasNotificacion del escritorio), con el id concreto")
        Destino destino) {

    /** pantalla: CONTRATO, INCIDENCIA, HABITACION o MENSAJES (id = contrato). */
    public record Destino(String pantalla, Integer id) {}

    private static final Pattern REFERENCIA = Pattern.compile(
            "^(contrato_vence|pago_pendiente|cobro_vencido|recordatorio_enviado|pago_atrasado|recordatorio_pago|incidencia_antigua|mantenimiento_largo|mensaje)_(\\d+)");

    public NotificacionResponse comoNoLeida() {
        return new NotificacionResponse(id, tipo, titulo, descripcion, fecha, false, destino);
    }

    public static NotificacionResponse de(Notificacion n) {
        return new NotificacionResponse(n.getId(), n.getTipo(), n.getTitulo(), n.getDescripcion(), Textos.conZona(n.getFecha()),
                n.isLeida(), destino(n.getReferencia()));
    }

    /** Las referencias del escritorio llevan el id: "contrato_vence_12", "pago_pendiente_12_2026_10"... */
    static Destino destino(String referencia) {
        if (referencia == null) return null;
        Matcher m = REFERENCIA.matcher(referencia);
        if (!m.find()) return null;
        String pantalla = switch (m.group(1)) {
            case "contrato_vence", "pago_pendiente", "cobro_vencido", "recordatorio_enviado",
                 "pago_atrasado", "recordatorio_pago" -> "CONTRATO";
            case "incidencia_antigua" -> "INCIDENCIA";
            case "mensaje" -> "MENSAJES";
            default -> "HABITACION";
        };
        return new Destino(pantalla, Integer.valueOf(m.group(2)));
    }
}
