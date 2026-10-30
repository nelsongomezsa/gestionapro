package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.Rol;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PerfilIntegrationTest extends IntegrationTest {

    @Test
    void ibanConDigitoDeControlMalo_400() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);
        mvc.perform(patch("/api/me").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"iban\":\"ES92 2100 0418 4502 0005 1332\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("IBAN_NO_VALIDO"));
    }

    @Test
    void soloCambiaLoEnviado_yUnIbanVacioLoBorra() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);
        String t = token("ana@test.com");
        mvc.perform(patch("/api/me").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"iban\":\"ES9121000418450200051332\",\"dni\":\"12345678Z\"}"))
                .andExpect(jsonPath("$.nombre").value("Usuario ana@test.com"))
                .andExpect(jsonPath("$.dni").value("12345678Z"));
        mvc.perform(patch("/api/me").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"iban\":\"\"}"))
                .andExpect(jsonPath("$.iban").doesNotExist())
                .andExpect(jsonPath("$.dni").value("12345678Z"));
    }

    @Test
    void emailDeOtraCuenta_409() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);
        datos.usuario("bea@test.com", Rol.PROPIETARIO);
        mvc.perform(patch("/api/me").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"email\":\"BEA@test.com\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("EMAIL_EN_USO"));
    }

    @Test
    void me_devuelveDniEIban() throws Exception {
        var u = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        u.setIban("ES9121000418450200051332");
        mvc.perform(get("/api/me").header("Authorization", token("ana@test.com")))
                .andExpect(jsonPath("$.iban").value("ES91 2100 0418 4502 0005 1332"));
    }
}
