package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;

import java.time.LocalDate;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Ataques de la auditoría de seguridad que motivaron un arreglo: cada test reproduce el ataque. */
class AtaquesIntegrationTest extends IntegrationTest {

    Habitacion habAna;
    Piso pisoAna;

    @BeforeEach
    void preparar() {
        Usuario ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        datos.usuario("bea@test.com", Rol.PROPIETARIO);
        pisoAna = datos.piso("Calle de Ana 1", datos.ciudad("Madrid"), ana);
        habAna = datos.habitacion(pisoAna, 1, EstadoHabitacion.disponible);
    }

    /** Un PDF "políglota" (cabecera %PDF con HTML y script dentro) pasa la comprobación de tipo:
     *  al servirlo, la política de contenido impide ejecutar nada aunque un navegador lo interprete. */
    @Test
    void pdfConHtmlDentro_seSirveConPoliticaQueImpideEjecutarlo() throws Exception {
        String t = token("ana@test.com");
        String gasto = mvc.perform(post("/api/gastos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idPiso", pisoAna.getId(), "categoria", "IBI", "concepto", "IBI",
                                "importe", "100.00", "fecha", LocalDate.now().toString()))))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        int id = leer(gasto).get("id").asInt();
        byte[] poliglota = "%PDF-1.4\n<html><script>alert(document.cookie)</script></html>\n%%EOF".getBytes();
        mvc.perform(multipart("/api/gastos/" + id + "/factura")
                        .file(new MockMultipartFile("archivo", "f.pdf", "application/pdf", poliglota)).header("Authorization", t))
                .andExpect(status().isOk());
        mvc.perform(get("/api/gastos/" + id + "/factura").header("Authorization", t))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Security-Policy", org.hamcrest.Matchers.containsString("sandbox")))
                .andExpect(header().string("Content-Security-Policy", org.hamcrest.Matchers.containsString("default-src 'none'")))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"));
        // Sin token, nada.
        mvc.perform(get("/api/gastos/" + id + "/factura")).andExpect(status().isUnauthorized());
    }

    @Test
    void cabecerasDeSeguridad_enTodaLaApi() throws Exception {
        mvc.perform(get("/api/me").header("Authorization", token("ana@test.com")))
                .andExpect(header().string("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; sandbox"))
                .andExpect(header().string("Referrer-Policy", "no-referrer"))
                .andExpect(header().string("X-Frame-Options", "DENY"));
        // También en los errores (una respuesta 401 tampoco debe poder ejecutar nada).
        mvc.perform(get("/api/me")).andExpect(header().exists("Content-Security-Policy"));
    }

    /** Antes: la lista de inventarios de una habitación ajena respondía 200 con lista vacía,
     *  confirmando que ese id existe. Ahora, 404 como el resto de recursos ajenos. */
    @Test
    void inventariosDeUnaHabitacionAjena_404() throws Exception {
        mvc.perform(get("/api/habitaciones/" + habAna.getId() + "/inventarios").header("Authorization", token("bea@test.com")))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/habitaciones/" + habAna.getId() + "/inventarios").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk());
    }
}
