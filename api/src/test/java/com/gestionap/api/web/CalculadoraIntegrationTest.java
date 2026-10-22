package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.Rol;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.util.HashMap;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** La lógica se comprueba en CalculadoraRentabilidadTest; aquí, el contrato HTTP. */
class CalculadoraIntegrationTest extends IntegrationTest {

    @Test
    void rentabilidad_casoMadridDelEscritorio_redondeadoADosDecimales() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Map<String, Object> req = new HashMap<>();
        req.put("comunidad", "Madrid");
        req.put("precioCompra", 200000);
        req.put("gastosNotariaRegistro", 2500);
        req.put("gastosHipoteca", 1500);
        req.put("reforma", 10000);
        req.put("comisionCompra", 3000);
        req.put("mobiliario", 4000);
        req.put("ibiMensual", 50);
        req.put("segurosMensual", 30);
        req.put("comunidadMensual", 80);
        req.put("mantenimientoMensual", 40);
        req.put("vacioMensual", 60);
        req.put("alquilerMensual", 1400);
        req.put("revalorizacionAnualPct", 3);
        req.put("porcentajeFinanciado", 80);
        req.put("plazoAnos", 25);
        req.put("tipoInteresPct", 3.2);

        mvc.perform(post("/api/calculadora/rentabilidad").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.itpImporte").value(12000.00))
                .andExpect(jsonPath("$.totalCompra").value(233000.00))
                .andExpect(jsonPath("$.cuotaMensual").value(775.49))
                .andExpect(jsonPath("$.interesesMensualesPromedio").value(242.16))
                .andExpect(jsonPath("$.rentabilidadBrutaPct").value(7.21))
                .andExpect(jsonPath("$.rentabilidadNetaPct").value(5.87))
                .andExpect(jsonPath("$.cashFlowMensual").value(364.51))
                .andExpect(jsonPath("$.aniosRecuperacion").value(16.69))
                .andExpect(jsonPath("$.plusvalia10Anios").value(68783.28));
    }

    @Test
    void rentabilidad_camposOpcionalesOmitidos_cuentanComoCero_ySinRevalorizacionNoHayPlusvalia() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);

        mvc.perform(post("/api/calculadora/rentabilidad").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("comunidad", "País Vasco", "precioCompra", 100000, "alquilerMensual", 600))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.itpImporte").value(4000.00))
                .andExpect(jsonPath("$.hipoteca").value(0.00))
                .andExpect(jsonPath("$.plusvalia5Anios").doesNotExist());
    }

    @Test
    void rentabilidad_comunidadDesconocida_400() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);

        mvc.perform(post("/api/calculadora/rentabilidad").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("comunidad", "Atlantis", "precioCompra", 1, "alquilerMensual", 1))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("COMUNIDAD_DESCONOCIDA"));
    }

    @Test
    void rentabilidad_porcentajeFinanciadoMayorQue100_400() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);

        mvc.perform(post("/api/calculadora/rentabilidad").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("comunidad", "Madrid", "precioCompra", 1, "alquilerMensual", 1,
                                "porcentajeFinanciado", 120))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errores[0].campo").value("porcentajeFinanciado"));
    }

    @Test
    void jsonMalformado_400() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);

        mvc.perform(post("/api/calculadora/rentabilidad").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content("{ esto no es json"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("JSON_INVALIDO"));
    }

    @Test
    void itp_lista19Comunidades() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);

        mvc.perform(get("/api/calculadora/itp").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.comunidades.length()").value(19))
                .andExpect(jsonPath("$.comunidades[?(@.nombre == 'Canarias')].tipoPct").value(6.5));
    }

    @Test
    void rutaInexistente_404EnJson() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);

        mvc.perform(get("/api/no-existe").header("Authorization", token("ana@test.com")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.codigo").value("RUTA_NO_ENCONTRADA"));
    }
}
