package com.gestionap.api.web.dto;

import com.gestionap.api.domain.EstadoHabitacion;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;
import java.time.LocalDate;

public record HabitacionResponse(
        Integer id,
        int numero,
        BigDecimal precio,
        EstadoHabitacion estado,
        PisoBreve piso,
        @Schema(description = "Inquilino del contrato activo hoy; ausente si no hay") InquilinoActual inquilinoActual,
        Integer idContratoActivo,
        @Schema(description = "Días desde el inicio del contrato activo") Long diasAlquilada,
        @Schema(description = "Libre (o en mantenimiento) desde el día siguiente al fin de su último contrato; ausente si está alquilada o nunca tuvo contrato") LocalDate libreDesde) {

    public record InquilinoActual(Integer id, String nombre) {}
}
