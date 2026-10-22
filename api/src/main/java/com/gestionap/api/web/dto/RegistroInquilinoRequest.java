package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RegistroInquilinoRequest(
        @Schema(description = "Código de invitación que generó el propietario", example = "K7M2-QX9P-4TBW")
        @NotBlank String codigo,
        @NotBlank @Email @Size(max = 100) String email,
        @NotBlank @Size(min = 8, max = 72, message = "debe tener entre 8 y 72 caracteres") String password) {}
