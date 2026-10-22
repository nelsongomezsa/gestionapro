package com.gestionap.api.web.dto;

import java.time.Instant;

public record TokenResponse(String token, String tipo, Instant expira, UsuarioResponse usuario) {

    public static TokenResponse bearer(String token, Instant expira, UsuarioResponse usuario) {
        return new TokenResponse(token, "Bearer", expira, usuario);
    }
}
