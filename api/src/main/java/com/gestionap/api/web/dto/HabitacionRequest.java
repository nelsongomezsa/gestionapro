package com.gestionap.api.web.dto;

import com.gestionap.api.domain.EstadoHabitacion;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record HabitacionRequest(
        @NotNull Integer idPiso,
        @NotNull @Min(1) @Max(999) Integer numero,
        @NotNull @DecimalMin(value = "0.01", message = "debe ser mayor que 0") @DecimalMax("99999.99")
        @Digits(integer = 6, fraction = 2) BigDecimal precio,
        @Schema(description = "Opcional; por defecto disponible") EstadoHabitacion estado) {}
