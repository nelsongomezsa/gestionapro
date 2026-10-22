package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;

/** Campos de la pantalla "Rentabilidad" del escritorio. Los importes mensuales son por mes. */
public record RentabilidadRequest(
        @Schema(example = "Madrid", description = "Nombre exacto, ver GET /api/calculadora/itp")
        @NotBlank String comunidad,
        @NotNull @PositiveOrZero Double precioCompra,
        @PositiveOrZero Double gastosNotariaRegistro,
        @PositiveOrZero Double gastosHipoteca,
        @PositiveOrZero Double reforma,
        @PositiveOrZero Double comisionCompra,
        @PositiveOrZero Double mobiliario,
        @PositiveOrZero Double ibiMensual,
        @PositiveOrZero Double segurosMensual,
        @PositiveOrZero Double comunidadMensual,
        @PositiveOrZero Double mantenimientoMensual,
        @Schema(description = "Provisión mensual por periodos sin inquilino")
        @PositiveOrZero Double vacioMensual,
        @NotNull @PositiveOrZero Double alquilerMensual,
        @PositiveOrZero Double revalorizacionAnualPct,
        @Schema(description = "% del precio de compra financiado con hipoteca")
        @PositiveOrZero @DecimalMax("100") Double porcentajeFinanciado,
        @Min(0) @Max(50) Integer plazoAnos,
        @PositiveOrZero @DecimalMax("100") Double tipoInteresPct) {}
