package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.util.HashMap;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class HabitacionIntegrationTest extends IntegrationTest {

    Usuario ana;
    Piso pisoAna;
    Piso pisoBea;
    Habitacion h1;
    Habitacion h2;
    Habitacion deBea;

    @BeforeEach
    void preparar() {
        Ciudad madrid = datos.ciudad("Madrid");
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Usuario bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        datos.usuario("admin@test.com", Rol.ADMIN);
        pisoAna = datos.piso("Calle de Ana 1", madrid, ana);
        pisoBea = datos.piso("Calle de Bea 2", madrid, bea);
        h1 = datos.habitacion(pisoAna, 1, EstadoHabitacion.alquilada);
        h2 = datos.habitacion(pisoAna, 2, EstadoHabitacion.disponible);
        deBea = datos.habitacion(pisoBea, 1, EstadoHabitacion.disponible);
        datos.contratoActivo(h1, datos.inquilino("11111111A", null), "450.00");
    }

    private Map<String, Object> habitacion(Integer idPiso, int numero, String precio) {
        Map<String, Object> m = new HashMap<>();
        m.put("idPiso", idPiso);
        m.put("numero", numero);
        m.put("precio", precio);
        return m;
    }

    @Test
    void propietario_soloVeLasDeSusPisos_conInquilinoActualYDias() throws Exception {
        mvc.perform(get("/api/habitaciones").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].numero").value(1))
                .andExpect(jsonPath("$[0].piso.direccion").value("Calle de Ana 1"))
                .andExpect(jsonPath("$[0].inquilinoActual.nombre").value("Ana García 11111111A"))
                .andExpect(jsonPath("$[0].diasAlquilada").isNumber())
                .andExpect(jsonPath("$[1].inquilinoActual").doesNotExist());
    }

    @Test
    void filtros_porPisoEstadoYTexto() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(get("/api/habitaciones").param("estado", "disponible").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].numero").value(2));
        mvc.perform(get("/api/habitaciones").param("q", "garcía").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1));
        mvc.perform(get("/api/habitaciones").param("piso", pisoBea.getId().toString()).header("Authorization", t))
                .andExpect(status().isNotFound());
    }

    @Test
    void admin_veTodas() throws Exception {
        mvc.perform(get("/api/habitaciones").header("Authorization", token("admin@test.com")))
                .andExpect(jsonPath("$.length()").value(3));
    }

    @Test
    void crear_editar_yBorrar() throws Exception {
        String t = token("ana@test.com");
        String cuerpo = mvc.perform(post("/api/habitaciones").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(habitacion(pisoAna.getId(), 3, "390.50"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.estado").value("disponible"))
                .andExpect(jsonPath("$.precio").value(390.50))
                .andReturn().getResponse().getContentAsString();
        int id = leer(cuerpo).get("id").asInt();

        var cambio = habitacion(pisoAna.getId(), 4, "410");
        cambio.put("estado", "mantenimiento");
        mvc.perform(put("/api/habitaciones/" + id).header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(cambio)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.numero").value(4))
                .andExpect(jsonPath("$.estado").value("mantenimiento"));

        mvc.perform(delete("/api/habitaciones/" + id).header("Authorization", t))
                .andExpect(status().isNoContent());
        mvc.perform(get("/api/habitaciones/" + id).header("Authorization", t))
                .andExpect(status().isNotFound());
    }

    @Test
    void numeroRepetidoEnElMismoPiso_409() throws Exception {
        mvc.perform(post("/api/habitaciones").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(habitacion(pisoAna.getId(), 2, "300"))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("NUMERO_HABITACION_DUPLICADO"));
    }

    @Test
    void crearEnPisoAjeno_404_yDatosInvalidos_400() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(post("/api/habitaciones").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(habitacion(pisoBea.getId(), 9, "300"))))
                .andExpect(status().isNotFound());
        mvc.perform(post("/api/habitaciones").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(habitacion(pisoAna.getId(), 0, "-5"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errores[?(@.campo == 'numero')]").exists())
                .andExpect(jsonPath("$.errores[?(@.campo == 'precio')]").exists());
    }

    @Test
    void cambiarEstado_yNoDejarDeEstarAlquiladaConContratoActivo() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(patch("/api/habitaciones/" + h2.getId() + "/estado").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"estado\":\"mantenimiento\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.estado").value("mantenimiento"));
        mvc.perform(patch("/api/habitaciones/" + h1.getId() + "/estado").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"estado\":\"disponible\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("HABITACION_CON_CONTRATO_ACTIVO"));
        mvc.perform(patch("/api/habitaciones/" + h2.getId() + "/estado").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"estado\":\"ocupadisima\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void borrarConContrato_409_yAjena_404() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(delete("/api/habitaciones/" + h1.getId()).header("Authorization", t))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("HABITACION_CON_HISTORIAL"));
        mvc.perform(delete("/api/habitaciones/" + deBea.getId()).header("Authorization", t))
                .andExpect(status().isNotFound());
    }

    @Test
    void inquilino_403() throws Exception {
        datos.usuario("inq@test.com", Rol.INQUILINO);
        mvc.perform(get("/api/habitaciones").header("Authorization", token("inq@test.com")))
                .andExpect(status().isForbidden());
    }
}
