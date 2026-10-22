package com.gestionap.api.security;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

/** HS256 exige una clave de al menos 256 bits: 32 caracteres ASCII como mínimo. */
@Validated
@ConfigurationProperties("gestionap.jwt")
public record JwtProperties(
        @NotBlank @Size(min = 32, message = "JWT_SECRET debe tener al menos 32 caracteres") String secret,
        @NotNull Duration expiracion) {}
