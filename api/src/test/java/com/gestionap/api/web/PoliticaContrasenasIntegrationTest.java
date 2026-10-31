package com.gestionap.api.web;

import com.gestionap.api.Datos;
import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.Rol;
import com.gestionap.api.security.ContrasenasFiltradas;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import java.util.Map;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Contraseñas nuevas: mínimo 10 caracteres y no filtradas (HIBP simulado). Contexto propio: H2 aparte. */
@TestPropertySource(properties = "spring.datasource.url=jdbc:h2:mem:politica;MODE=MySQL")
class PoliticaContrasenasIntegrationTest extends IntegrationTest {

    static final String FILTRADA = "password1234";

    @MockitoBean ContrasenasFiltradas filtradas;

    @BeforeEach
    void preparar() {
        when(filtradas.filtrada(anyString())).thenReturn(false);
        when(filtradas.filtrada(FILTRADA)).thenReturn(true);
        datos.usuario("ana@test.com", Rol.PROPIETARIO);
        datos.usuario("admin@test.com", Rol.ADMIN);
    }

    @Test
    void cambiarPassword_filtrada_400_yCorta_400() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(put("/api/me/password").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("actual", Datos.PASSWORD, "nueva", FILTRADA))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("PASSWORD_FILTRADA"));
        mvc.perform(put("/api/me/password").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("actual", Datos.PASSWORD, "nueva", "nueve9999"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("VALIDACION"));
        mvc.perform(put("/api/me/password").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("actual", Datos.PASSWORD, "nueva", "Otra-frase-larga-2026"))))
                .andExpect(status().is2xxSuccessful());
    }

    @Test
    void crearUsuario_conContrasenaFiltrada_400() throws Exception {
        mvc.perform(post("/api/usuarios").header("Authorization", token("admin@test.com")).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("nombre", "Carla", "email", "carla@test.com", "password", FILTRADA, "rol", "PROPIETARIO"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("PASSWORD_FILTRADA"));
    }
}
