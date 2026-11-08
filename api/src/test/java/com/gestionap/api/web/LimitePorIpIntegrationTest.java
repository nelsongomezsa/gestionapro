package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;

import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Límite por IP en login y registro (auditoría): al superarlo, 429 con Retry-After para cualquier email. */
@TestPropertySource(properties = {"gestionap.limites.por-ip=3", "spring.datasource.url=jdbc:h2:mem:limiteip;MODE=MySQL"})
class LimitePorIpIntegrationTest extends IntegrationTest {

    @Test
    void porIp_alCuartoIntento_429ConRetryAfter_tambienEnRegistro() throws Exception {
        for (int i = 0; i < 3; i++) {
            mvc.perform(post("/api/auth/login").with(r -> { r.setRemoteAddr("203.0.113.7"); return r; })
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(json(Map.of("email", "ip" + i + "@test.com", "password", "mala-mala"))))
                    .andExpect(status().isUnauthorized());
        }
        mvc.perform(post("/api/auth/login").with(r -> { r.setRemoteAddr("203.0.113.7"); return r; })
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "otro@test.com", "password", "mala-mala"))))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"));
        mvc.perform(post("/api/auth/register-inquilino").with(r -> { r.setRemoteAddr("203.0.113.7"); return r; })
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("codigo", "AAAA-BBBB-CCCC", "email", "n@test.com", "password", "Larga-y-rara-2026"))))
                .andExpect(status().isTooManyRequests());
        // Otra IP no queda bloqueada.
        mvc.perform(post("/api/auth/login").with(r -> { r.setRemoteAddr("198.51.100.9"); return r; })
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "otro@test.com", "password", "mala-mala"))))
                .andExpect(status().isUnauthorized());
    }
}
