package com.gestionap.api.web.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ContratoRequest(
        @NotNull Integer idHabitacion,
        @NotNull Integer idInquilino,
        @NotNull LocalDate fechaInicio,
        @NotNull LocalDate fechaFin,
        @NotNull @DecimalMin(value = "0.01", message = "debe ser mayor que 0") @DecimalMax("99999.99")
        @Digits(integer = 6, fraction = 2) BigDecimal precioMensual) {}
