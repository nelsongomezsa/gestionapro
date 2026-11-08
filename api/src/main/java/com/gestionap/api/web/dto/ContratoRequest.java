package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ContratoRequest(
        @NotNull Integer idHabitacion,
        @NotNull Integer idInquilino,
        @NotNull LocalDate fechaInicio,
        @NotNull LocalDate fechaFin,
        @NotNull @DecimalMin(value = "0.01", message = "debe ser mayor que 0") @DecimalMax("99999.99")
        @Digits(integer = 6, fraction = 2) BigDecimal precioMensual,
        @Schema(description = "Solo plazas y trasteros: el recibo desglosa base e IVA. Por defecto, sin IVA")
        Boolean aplicaIva,
        @Schema(description = "Porcentaje de IVA si aplicaIva (por defecto 21)")
        @DecimalMin(value = "0.01", message = "debe ser mayor que 0") @DecimalMax("30") @Digits(integer = 2, fraction = 2)
        BigDecimal ivaPct) {

    public ContratoRequest(Integer idHabitacion, Integer idInquilino, LocalDate fechaInicio, LocalDate fechaFin,
                           BigDecimal precioMensual) {
        this(idHabitacion, idInquilino, fechaInicio, fechaFin, precioMensual, null, null);
    }
}
