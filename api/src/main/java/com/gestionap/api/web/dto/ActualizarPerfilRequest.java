package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** PATCH: los campos que no se envían no cambian. Un DNI o IBAN vacío ("") se borra. */
public record ActualizarPerfilRequest(
        @Size(min = 1, max = 100) String nombre,
        @Email @Size(max = 100) String email,
        @Pattern(regexp = "(?i)|[0-9]{8}[A-Z]|[XYZ][0-9]{7}[A-Z]", message = "debe ser un DNI o un NIE") String dni,
        @Schema(description = "Se admite con espacios; se valida el dígito de control", example = "ES91 2100 0418 4502 0005 1332")
        @Size(max = 42) String iban) {}
