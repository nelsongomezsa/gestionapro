package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import org.junit.jupiter.api.Test;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** La plataforma de despliegue comprueba /actuator/health sin sesión; no debe dar detalles. */
class SaludTest extends IntegrationTest {

    @Test
    void salud_sinSesion_ySinDetalles() throws Exception {
        mvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.components").doesNotExist());
        mvc.perform(get("/actuator/env")).andExpect(status().is4xxClientError());
    }
}
