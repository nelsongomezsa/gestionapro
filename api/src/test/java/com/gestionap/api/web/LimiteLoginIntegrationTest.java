package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.Rol;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class LimiteLoginIntegrationTest extends IntegrationTest {

    private org.springframework.test.web.servlet.ResultActions login(String email, String password) throws Exception {
        return mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("email", email, "password", password))));
    }

    @Test
    void login_trasCincoFallos_429ConRetryAfter_eInclusoConLaContrasenaBuena() throws Exception {
        datos.usuario("limite@test.com", Rol.PROPIETARIO);
        for (int i = 0; i < 5; i++) login("limite@test.com", "mala").andExpect(status().isUnauthorized());

        login("limite@test.com", com.gestionap.api.Datos.PASSWORD)
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"))
                .andExpect(jsonPath("$.codigo").value("DEMASIADOS_INTENTOS"))
                .andExpect(jsonPath("$.mensaje").value(org.hamcrest.Matchers.startsWith("Demasiados intentos. Prueba de nuevo en ")));
    }

    @Test
    void registroInquilino_codigosFallidos_tambienSeLimitan() throws Exception {
        var cuerpo = json(Map.of("codigo", "AAAA-BBBB-CCCC", "email", "nuevo.limite@test.com", "password", "Larga-y-rara-2026"));
        for (int i = 0; i < 5; i++) {
            mvc.perform(post("/api/auth/register-inquilino").contentType(MediaType.APPLICATION_JSON).content(cuerpo))
                    .andExpect(status().isBadRequest());
        }
        mvc.perform(post("/api/auth/register-inquilino").contentType(MediaType.APPLICATION_JSON).content(cuerpo))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));
    }
}
