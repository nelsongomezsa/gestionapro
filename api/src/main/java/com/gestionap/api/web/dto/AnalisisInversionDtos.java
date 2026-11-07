package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;

/** Análisis de inversión guardados (simulaciones de la calculadora con nombre). */
public final class AnalisisInversionDtos {
    private AnalisisInversionDtos() {}

    /** Solo estos campos: el dueño lo pone la API (sin asignación masiva). */
    public record AnalisisInversionRequest(
            @NotBlank @Size(max = 80) String nombre,
            @Schema(description = "Piso del que salen los datos (opcional); debe ser tuyo") Integer idPiso,
            @NotNull @Valid RentabilidadRequest entrada) {}

    public record AnalisisInversionResponse(
            Integer id,
            String nombre,
            Integer idPiso,
            OffsetDateTime fecha,
            RentabilidadRequest entrada,
            @Schema(description = "Recalculado al leer, con los tipos de ITP vigentes") RentabilidadResponse resultado) {}
}
