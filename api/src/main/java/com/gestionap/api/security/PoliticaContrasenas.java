package com.gestionap.api.security;

import com.gestionap.api.web.ApiException;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;

/** Reglas para cualquier contraseña nueva: 10 caracteres como mínimo, 72 bytes como máximo (BCrypt) y no filtrada. */
@Component
public class PoliticaContrasenas {

    public static final int MINIMO = 10;
    /** BCrypt solo usa los primeros 72 bytes; más largo se rechaza en vez de truncarlo en silencio. */
    public static final int MAX_BYTES = 72;

    private final ContrasenasFiltradas filtradas;

    public PoliticaContrasenas(ContrasenasFiltradas filtradas) {
        this.filtradas = filtradas;
    }

    public void exigir(String password) {
        if (password == null || password.codePointCount(0, password.length()) < MINIMO) {
            throw ApiException.badRequest("PASSWORD_CORTA", "La contraseña debe tener al menos " + MINIMO + " caracteres");
        }
        if (password.getBytes(StandardCharsets.UTF_8).length > MAX_BYTES) {
            throw ApiException.badRequest("PASSWORD_DEMASIADO_LARGA", "La contraseña es demasiado larga");
        }
        if (filtradas.filtrada(password)) {
            throw ApiException.badRequest("PASSWORD_FILTRADA",
                    "Esta contraseña aparece en filtraciones de datos conocidas. Elige otra.");
        }
    }
}
