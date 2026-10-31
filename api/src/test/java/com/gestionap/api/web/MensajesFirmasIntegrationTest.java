package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class MensajesFirmasIntegrationTest extends IntegrationTest {

    final LocalDate hoy = LocalDate.now();
    Inquilino lucia;
    Inquilino pedro;
    Contrato deLucia;
    Contrato dePedro;
    Incidencia gotera;

    @BeforeEach
    void preparar() {
        Usuario ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        datos.usuario("bea@test.com", Rol.PROPIETARIO);
        Piso piso = datos.piso("Calle de Ana 1", datos.ciudad("Madrid"), ana);
        Habitacion h1 = datos.habitacion(piso, 1, EstadoHabitacion.alquilada);
        Habitacion h2 = datos.habitacion(piso, 2, EstadoHabitacion.alquilada);
        lucia = datos.inquilinoDe(ana, "11111111A");
        lucia.setUsuario(datos.usuario("lucia@test.com", Rol.INQUILINO));
        pedro = datos.inquilinoDe(ana, "22222222B");
        deLucia = datos.contrato(h1, lucia, "450.00", hoy.minusMonths(2), hoy.plusMonths(10));
        dePedro = datos.contrato(h2, pedro, "400.00", hoy.minusMonths(2), hoy.plusMonths(10));
        gotera = datos.incidencia(h1, lucia, "Gotera en el techo");
    }

    private String mensaje(String texto, Integer incidencia) throws Exception {
        return incidencia == null ? json(Map.of("texto", texto)) : json(Map.of("texto", texto, "idIncidencia", incidencia));
    }

    @Test
    void conversacion_propietarioEInquilino_conAvisoYLeidos() throws Exception {
        String ta = token("ana@test.com");
        String tl = token("lucia@test.com");
        String url = "/api/contratos/" + deLucia.getId() + "/mensajes";
        mvc.perform(post(url).header("Authorization", ta).contentType(MediaType.APPLICATION_JSON).content(mensaje("Hola, Lucía", null)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.mio").value(true));
        mvc.perform(post(url).header("Authorization", ta).contentType(MediaType.APPLICATION_JSON).content(mensaje("¿Todo bien?", null)))
                .andExpect(status().isCreated());
        // Un solo aviso sin leer para la conversación, no uno por mensaje.
        mvc.perform(get("/api/notificaciones").header("Authorization", tl))
                .andExpect(jsonPath("$[?(@.tipo == 'mensaje')]").value(org.hamcrest.Matchers.hasSize(1)));
        mvc.perform(get("/api/conversaciones").header("Authorization", tl))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].sinLeer").value(2))
                .andExpect(jsonPath("$[0].ultimoMensaje").value("¿Todo bien?"));
        mvc.perform(get(url).header("Authorization", tl))
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].mio").value(false));
        mvc.perform(get("/api/conversaciones").header("Authorization", tl)).andExpect(jsonPath("$[0].sinLeer").value(0));
        mvc.perform(post(url).header("Authorization", tl).contentType(MediaType.APPLICATION_JSON).content(mensaje("Sí, gracias", null)))
                .andExpect(status().isCreated());
        mvc.perform(get("/api/conversaciones").header("Authorization", ta)).andExpect(jsonPath("$[0].sinLeer").value(1));
    }

    @Test
    void hiloDeIncidencia_separado_yValidado() throws Exception {
        String tl = token("lucia@test.com");
        String url = "/api/contratos/" + deLucia.getId() + "/mensajes";
        mvc.perform(post(url).header("Authorization", tl).contentType(MediaType.APPLICATION_JSON).content(mensaje("Sigue goteando", gotera.getId())))
                .andExpect(status().isCreated());
        mvc.perform(get(url).header("Authorization", tl)).andExpect(jsonPath("$.length()").value(0));
        mvc.perform(get(url).param("incidencia", gotera.getId().toString()).header("Authorization", tl))
                .andExpect(jsonPath("$.length()").value(1));
        mvc.perform(get("/api/conversaciones").header("Authorization", token("ana@test.com")))
                .andExpect(jsonPath("$[0].asunto").value(org.hamcrest.Matchers.startsWith("Incidencia: Gotera")));
        // Lo mismo desde la incidencia, sin saber el contrato.
        mvc.perform(get("/api/incidencias/" + gotera.getId() + "/mensajes").header("Authorization", token("ana@test.com")))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].texto").value("Sigue goteando"));
        mvc.perform(get("/api/incidencias/" + gotera.getId() + "/mensajes").header("Authorization", token("bea@test.com")))
                .andExpect(status().isNotFound());
        // Una incidencia de otro contrato no vale.
        mvc.perform(post("/api/contratos/" + dePedro.getId() + "/mensajes").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(mensaje("x", gotera.getId())))
                .andExpect(jsonPath("$.codigo").value("INCIDENCIA_NO_VALIDA"));
    }

    @Test
    void acceso_cadaUnoSoloLoSuyo_yInquilinoSinCuenta() throws Exception {
        String tl = token("lucia@test.com");
        mvc.perform(get("/api/contratos/" + dePedro.getId() + "/mensajes").header("Authorization", tl)).andExpect(status().isNotFound());
        mvc.perform(get("/api/contratos/" + deLucia.getId() + "/mensajes").header("Authorization", token("bea@test.com")))
                .andExpect(status().isNotFound());
        mvc.perform(post("/api/contratos/" + dePedro.getId() + "/mensajes").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(mensaje("Hola", null)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("INQUILINO_SIN_CUENTA"));
    }

    private MockMultipartFile firma() {
        return new MockMultipartFile("archivo", "firma.png", "image/png", FotosInventarioIntegrationTest.PNG);
    }

    @Test
    void firma_lasDosPartes_pdfFirmado_yCaducaSiCambiaElContrato() throws Exception {
        String ta = token("ana@test.com");
        String tl = token("lucia@test.com");
        String base = "/api/contratos/" + deLucia.getId();
        mvc.perform(get(base + "/pdf-firmado").header("Authorization", ta)).andExpect(status().isConflict());
        mvc.perform(multipart(base + "/firmas/ARRENDATARIO").file(firma()).header("Authorization", tl))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.firmas.length()").value(1))
                .andExpect(jsonPath("$.completo").value(false));
        // El inquilino no firma por el propietario.
        mvc.perform(multipart(base + "/firmas/ARRENDADOR").file(firma()).header("Authorization", tl)).andExpect(status().isForbidden());
        mvc.perform(multipart(base + "/firmas/ARRENDATARIO").file(firma()).header("Authorization", tl))
                .andExpect(jsonPath("$.codigo").value("YA_FIRMADO"));
        mvc.perform(multipart(base + "/firmas/ARRENDADOR").file(firma()).header("Authorization", ta))
                .andExpect(jsonPath("$.completo").value(true))
                .andExpect(jsonPath("$.firmas[1].nombre").value(org.hamcrest.Matchers.startsWith("Usuario ana")));
        var pdf = mvc.perform(get(base + "/pdf-firmado").header("Authorization", tl)).andExpect(status().isOk())
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(new String(pdf, 0, 5)).isEqualTo("%PDF-");
        // Si cambia la renta, las firmas dejan de valer y se puede volver a firmar.
        deLucia.setPrecioMensual(new BigDecimal("470.00"));
        mvc.perform(get(base + "/firmas").header("Authorization", ta))
                .andExpect(jsonPath("$.completo").value(false))
                .andExpect(jsonPath("$.cambiadoTrasFirmar").value(true));
        mvc.perform(multipart(base + "/firmas/ARRENDATARIO").file(firma()).header("Authorization", tl)).andExpect(status().isOk());
        mvc.perform(get(base + "/firmas").header("Authorization", token("bea@test.com"))).andExpect(status().isNotFound());
    }
}
