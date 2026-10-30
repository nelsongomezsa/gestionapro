package com.gestionap.api.web.dto;

import com.gestionap.api.domain.EstadoHabitacion;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;

public record HabitacionResponse(
        Integer id,
        int numero,
        BigDecimal precio,
        EstadoHabitacion estado,
        PisoBreve piso,
        @Schema(description = "Inquilino del contrato activo hoy; ausente si no hay") InquilinoActual inquilinoActual,
        Integer idContratoActivo,
        @Schema(description = "Días desde el inicio del contrato activo") Long diasAlquilada) {

    public record InquilinoActual(Integer id, String nombre) {}
}
