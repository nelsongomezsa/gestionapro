package com.gestionap.api.web.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;

public record DevolucionFianzaRequest(
        @NotNull LocalDate fechaDevolucion,
        @NotNull @DecimalMin("0.00") @Digits(integer = 6, fraction = 2) BigDecimal importeDevuelto,
        @Size(max = 255) String motivoRetencion) {
}
