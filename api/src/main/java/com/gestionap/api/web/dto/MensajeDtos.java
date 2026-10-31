package com.gestionap.api.web.dto;

import com.gestionap.api.domain.Mensaje;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;

public final class MensajeDtos {

    private MensajeDtos() {}

    public record MensajeRequest(@NotBlank @Size(max = 2000) String texto, Integer idIncidencia) {}

    public record MensajeResponse(Integer id, Integer idContrato, Integer idIncidencia, String autor, boolean mio,
                                  String texto, OffsetDateTime fecha, boolean leido) {

        public static MensajeResponse de(Mensaje m, Integer idLector) {
            boolean mio = m.getAutor() != null && m.getAutor().getId().equals(idLector);
            return new MensajeResponse(m.getId(), m.getContrato().getId(), m.getIdIncidencia(),
                    m.getAutor() != null ? m.getAutor().getNombre() : "Usuario eliminado", mio, m.getTexto(),
                    com.gestionap.api.service.Textos.conZona(m.getFecha()), m.isLeido());
        }
    }

    /** Una conversación de la bandeja: contrato (e incidencia si la hay), con quién, último mensaje y sin leer. */
    public record Conversacion(Integer idContrato, Integer idIncidencia, String con, String asunto,
                               String ultimoMensaje, OffsetDateTime fecha, boolean ultimoMio, long sinLeer) {}
}
