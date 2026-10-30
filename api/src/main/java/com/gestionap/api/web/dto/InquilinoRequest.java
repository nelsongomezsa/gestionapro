package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;

/** Mismas reglas que el formulario del escritorio, más NIE (X/Y/Z + 7 cifras + letra). */
public record InquilinoRequest(
        @NotBlank @Size(max = 100) String nombre,
        @NotBlank @Size(max = 100) String apellidos,
        @Schema(example = "12345678Z")
        @NotBlank @Pattern(regexp = "(?i)[0-9]{8}[A-Z]|[XYZ][0-9]{7}[A-Z]", message = "debe ser un DNI (8 cifras y letra) o un NIE")
        String dni,
        @Schema(example = "633 456 789")
        @Pattern(regexp = "\\+?(?:[0-9] ?){8,14}[0-9]", message = "debe tener entre 9 y 15 cifras, con + y espacios opcionales")
        String telefono,
        @Email @Size(max = 100) String email) {}
