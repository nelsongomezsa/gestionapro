package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;

import java.time.LocalDate;
import java.util.Base64;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class FotosInventarioIntegrationTest extends IntegrationTest {

    /** PNG de 1 × 1 píxeles: lo bastante real para incrustarlo en el PDF. */
    static final byte[] PNG = Base64.getDecoder().decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==");

    final LocalDate hoy = LocalDate.now();
    Inquilino lucia;
    Habitacion hab;
    Contrato contrato;
    Incidencia incidencia;

    @BeforeEach
    void preparar() {
        Usuario ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        datos.usuario("bea@test.com", Rol.PROPIETARIO);
        hab = datos.habitacion(datos.piso("Calle de Ana 1", datos.ciudad("Madrid"), ana), 1, EstadoHabitacion.alquilada);
        lucia = datos.inquilinoDe(ana, "11111111A");
        lucia.setUsuario(datos.usuario("lucia@test.com", Rol.INQUILINO));
        contrato = datos.contrato(hab, lucia, "450.00", hoy.minusMonths(2), hoy.plusMonths(10));
        incidencia = datos.incidencia(hab, lucia, "Gotera en el techo");
    }

    private MockMultipartFile archivo(byte[] datos, String nombre) {
        return new MockMultipartFile("archivo", nombre, "application/octet-stream", datos);
    }

    @Test
    void fotosDeIncidencia_lasSubeElInquilino_yLasVeElPropietario() throws Exception {
        String tl = token("lucia@test.com");
        String url = "/api/incidencias/" + incidencia.getId() + "/fotos";
        var res = mvc.perform(multipart(url).file(archivo(PNG, "gotera.png")).header("Authorization", tl))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.tipo").value("image/png"))
                .andExpect(jsonPath("$.mia").value(true))
                .andReturn().getResponse().getContentAsString();
        int id = com.jayway.jsonpath.JsonPath.read(res, "$.id");
        String ta = token("ana@test.com");
        mvc.perform(get(url).header("Authorization", ta))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].mia").value(false));
        var bytes = mvc.perform(get("/api/incidencias/fotos/" + id).header("Authorization", ta))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_PNG))
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(bytes).isEqualTo(PNG);
        // Otro propietario no la ve.
        mvc.perform(get("/api/incidencias/fotos/" + id).header("Authorization", token("bea@test.com")))
                .andExpect(status().isNotFound());
    }

    @Test
    void soloSeAdmitenFotos_yConElTipoReal() throws Exception {
        String url = "/api/incidencias/" + incidencia.getId() + "/fotos";
        String t = token("ana@test.com");
        // Un texto con extensión .png sigue siendo texto.
        mvc.perform(multipart(url).file(archivo("hola".getBytes(), "falso.png")).header("Authorization", t))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("TIPO_NO_ADMITIDO"));
        mvc.perform(multipart(url).file(archivo("%PDF-1.4 x\n%%EOF".getBytes(), "doc.pdf")).header("Authorization", t))
                .andExpect(jsonPath("$.codigo").value("TIPO_NO_ADMITIDO"));
        // Cabecera de PNG pero imagen cortada: dañada.
        mvc.perform(multipart(url).file(archivo(java.util.Arrays.copyOf(PNG, 20), "cortada.png")).header("Authorization", t))
                .andExpect(jsonPath("$.codigo").value("ARCHIVO_DANADO"));
    }

    @Test
    void inventario_crearConFotoYPdf_yElInquilinoLoVe() throws Exception {
        String t = token("ana@test.com");
        var cuerpo = Map.of("tipo", "ENTRADA", "fecha", hoy.toString(), "idContrato", contrato.getId(),
                "elementos", List.of(Map.of("nombre", "Cama", "estado", "BUENO"),
                        Map.of("nombre", "Pared", "estado", "DANADO", "observaciones", "Desconchón junto a la ventana")));
        var res = mvc.perform(post("/api/habitaciones/" + hab.getId() + "/inventarios").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(cuerpo)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.elementos.length()").value(2))
                .andExpect(jsonPath("$.inquilino").value(org.hamcrest.Matchers.containsString("Ana")))
                .andReturn().getResponse().getContentAsString();
        int idInv = com.jayway.jsonpath.JsonPath.read(res, "$.id");
        int idPared = com.jayway.jsonpath.JsonPath.read(res, "$.elementos[1].id");
        mvc.perform(multipart("/api/inventarios/elementos/" + idPared + "/foto").file(archivo(PNG, "pared.png")).header("Authorization", t))
                .andExpect(jsonPath("$.elementos[1].tieneFoto").value(true));
        var pdf = mvc.perform(get("/api/inventarios/" + idInv + "/pdf").header("Authorization", t))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(new String(pdf, 0, 5)).isEqualTo("%PDF-");

        String tl = token("lucia@test.com");
        mvc.perform(get("/api/habitaciones/" + hab.getId() + "/inventarios").header("Authorization", tl))
                .andExpect(jsonPath("$.length()").value(1));
        mvc.perform(get("/api/inventarios/" + idInv + "/pdf").header("Authorization", tl)).andExpect(status().isOk());
        mvc.perform(delete("/api/inventarios/" + idInv).header("Authorization", tl)).andExpect(status().isForbidden());
        mvc.perform(get("/api/inventarios/" + idInv).header("Authorization", token("bea@test.com"))).andExpect(status().isNotFound());
    }

    @Test
    void inventario_validaElContratoYLosElementos() throws Exception {
        String t = token("ana@test.com");
        Habitacion otra = datos.habitacion(hab.getPiso(), 2, EstadoHabitacion.disponible);
        var cuerpo = Map.of("tipo", "SALIDA", "fecha", hoy.toString(), "idContrato", contrato.getId(),
                "elementos", List.of(Map.of("nombre", "Cama", "estado", "BUENO")));
        mvc.perform(post("/api/habitaciones/" + otra.getId() + "/inventarios").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(cuerpo)))
                .andExpect(jsonPath("$.codigo").value("CONTRATO_NO_VALIDO"));
        mvc.perform(post("/api/habitaciones/" + hab.getId() + "/inventarios").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("tipo", "SALIDA", "fecha", hoy.toString(), "elementos", List.of()))))
                .andExpect(status().isBadRequest());
    }
}
