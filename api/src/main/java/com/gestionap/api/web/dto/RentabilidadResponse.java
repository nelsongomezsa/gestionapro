package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;

/** Importes y porcentajes redondeados a 2 decimales (como los muestra el escritorio). */
public record RentabilidadResponse(
        BigDecimal itpPct,
        BigDecimal itpImporte,
        BigDecimal totalCompra,
        BigDecimal gastosMensuales,
        BigDecimal gastosAnuales,
        BigDecimal alquilerAnual,
        BigDecimal hipoteca,
        BigDecimal capitalAportado,
        BigDecimal cuotaMensual,
        BigDecimal interesesMensualesPromedio,
        BigDecimal amortizacionMensualPromedio,
        BigDecimal rentabilidadBrutaPct,
        BigDecimal rentabilidadNetaPct,
        BigDecimal cashFlowMensual,
        BigDecimal cashFlowAnual,
        @Schema(description = "null si el cash flow no es positivo")
        BigDecimal aniosRecuperacion,
        @Schema(description = "null si no hay revalorización")
        BigDecimal plusvalia5Anios,
        BigDecimal plusvalia10Anios) {}
