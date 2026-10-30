package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;

public record QrPagoResponse(
        @Schema(description = "Texto del QR SEPA (EPC069-12, versión 002). La app lo convierte en imagen.")
        String payload,
        String beneficiario,
        @Schema(example = "ES91 2100 0418 4502 0005 1332") String iban,
        BigDecimal importe,
        String concepto) {}
