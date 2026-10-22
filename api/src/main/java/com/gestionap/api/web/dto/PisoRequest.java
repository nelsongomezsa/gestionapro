package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

public record PisoRequest(
        @NotBlank @Size(max = 150) String direccion,
        @NotNull @Min(1) @Max(50) Integer numeroHabitaciones,
        @NotNull Integer idCiudad,
        @Schema(description = "Opcional. En un PUT, si se omite, los datos financieros guardados no cambian")
        @Valid DatosFinancierosDto datosFinancieros) {}
