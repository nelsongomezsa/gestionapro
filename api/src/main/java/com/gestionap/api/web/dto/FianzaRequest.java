package com.gestionap.api.web.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;

public record FianzaRequest(
        @NotNull @DecimalMin("0.01") @Digits(integer = 6, fraction = 2) BigDecimal importe,
        LocalDate fechaCobro,
        LocalDate fechaDeposito,
        @Size(max = 150) String organismoDeposito,
        @Size(max = 100) String referenciaDeposito,
        @Size(max = 2000) String notas) {
}
