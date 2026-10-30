package com.gestionap.api.web.dto;

import com.gestionap.api.domain.MetodoPago;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PagoRequest(
        @NotNull Integer idContrato,
        @NotNull @DecimalMin(value = "0.01", message = "debe ser mayor que 0") @DecimalMax("99999.99")
        @Digits(integer = 6, fraction = 2) BigDecimal cantidad,
        @Schema(description = "Por defecto transferencia") MetodoPago metodoPago,
        @NotNull @PastOrPresent(message = "no puede ser una fecha futura") LocalDate fechaPago) {}
