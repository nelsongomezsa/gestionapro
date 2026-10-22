package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Tabla DatosPiso. Los importes omitidos cuentan como 0, igual que en el escritorio. */
public record DatosFinancierosDto(
        @PositiveOrZero BigDecimal precioCompra,
        @PositiveOrZero BigDecimal itpPagado,
        @PositiveOrZero BigDecimal gastosNotaria,
        @PositiveOrZero BigDecimal gastosRegistro,
        @PositiveOrZero BigDecimal costeReforma,
        @PositiveOrZero BigDecimal costeMobiliario,
        @PositiveOrZero BigDecimal otrosGastosCompra,
        boolean tieneHipoteca,
        @Schema(description = "Se guarda como 0 si tieneHipoteca es false")
        @PositiveOrZero BigDecimal importeHipoteca,
        @PositiveOrZero @DecimalMax("100") BigDecimal tipoInteres,
        @Min(0) @Max(50) Integer plazoAnos,
        @Schema(accessMode = Schema.AccessMode.READ_ONLY, description = "Calculada (amortización francesa)")
        BigDecimal cuotaMensualHipoteca,
        @PositiveOrZero BigDecimal gastoIbiAnual,
        @PositiveOrZero BigDecimal gastoComunidadMensual,
        @PositiveOrZero BigDecimal gastoSeguroAnual,
        @PositiveOrZero BigDecimal gastoMantenimientoAnual,
        @PositiveOrZero BigDecimal valorMercadoActual,
        LocalDate fechaCompra,
        @Size(max = 5000) String notas) {}
