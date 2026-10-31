package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class IncidenciaIntegrationTest extends IntegrationTest {

    final LocalDate hoy = LocalDate.now();
    Piso pisoAna;
    Habitacion alquilada;
    Habitacion libre;
    Inquilino lucia;
    Incidencia grifo;
    Incidencia deBea;

    @BeforeEach
    void preparar() {
        Ciudad madrid = datos.ciudad("Madrid");
        Usuario ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Usuario bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        pisoAna = datos.piso("Calle de Ana 1", madrid, ana);
        Piso pisoBea = datos.piso("Calle de Bea 2", madrid, bea);
        alquilada = datos.habitacion(pisoAna, 1, EstadoHabitacion.alquilada);
        libre = datos.habitacion(pisoAna, 2, EstadoHabitacion.disponible);
        lucia = datos.inquilinoDe(ana, "11111111A");
        Contrato c = datos.contrato(alquilada, lucia, "450.00", hoy.minusMonths(2), hoy.plusMonths(10));
        datos.pago(c, "450.00", hoy);
        grifo = datos.incidencia(alquilada, lucia, "Grifo que gotea");
        Habitacion hb = datos.habitacion(pisoBea, 1, EstadoHabitacion.alquilada);
        deBea = datos.incidencia(hb, datos.inquilinoDe(bea, "22222222B"), "Persiana rota");
    }

    private Map<String, Object> nueva(Integer idHabitacion, String descripcion) {
        Map<String, Object> m = new HashMap<>();
        m.put("idHabitacion", idHabitacion);
        m.put("descripcion", descripcion);
        return m;
    }

    @Test
    void propietario_listaFiltraYNoVeLasDeOtros() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(get("/api/incidencias").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].descripcion").value("Grifo que gotea"))
                .andExpect(jsonPath("$[0].inquilino.nombre").value("Ana García 11111111A"));
        mvc.perform(get("/api/incidencias").param("estado", "resuelta").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(0));
        mvc.perform(get("/api/incidencias/" + deBea.getId()).header("Authorization", t))
                .andExpect(status().isNotFound());
    }

    @Test
    void crear_usaElInquilinoDelContratoActivo_ySinContratoLoExige() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(post("/api/incidencias").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(nueva(alquilada.getId(), "No funciona la calefacción"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.estado").value("pendiente"))
                .andExpect(jsonPath("$.inquilino.id").value(lucia.getId()))
                .andExpect(jsonPath("$.fecha").value(hoy.toString()));
        mvc.perform(post("/api/incidencias").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(nueva(libre.getId(), "Pintar"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("INQUILINO_REQUERIDO"));
        var conInquilino = nueva(libre.getId(), "Pintar");
        conInquilino.put("idInquilino", lucia.getId());
        mvc.perform(post("/api/incidencias").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(conInquilino)))
                .andExpect(status().isCreated());
        // Un inquilino de otro piso del mismo propietario no: vería en su app una incidencia ajena.
        Piso otroPiso = datos.piso("Calle de Ana 9", alquilada.getPiso().getCiudad(), alquilada.getPiso().getPropietario());
        Inquilino deOtroPiso = datos.inquilinoDe(alquilada.getPiso().getPropietario(), "33333333C");
        datos.contrato(datos.habitacion(otroPiso, 1, EstadoHabitacion.alquilada), deOtroPiso, "400.00", hoy.minusMonths(1), hoy.plusMonths(11));
        var ajeno = nueva(libre.getId(), "Pintar");
        ajeno.put("idInquilino", deOtroPiso.getId());
        mvc.perform(post("/api/incidencias").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(ajeno)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("INQUILINO_NO_VALIDO"));
    }

    @Test
    void avanzarEstado_pendienteEnProcesoResuelta() throws Exception {
        String t = token("ana@test.com");
        String url = "/api/incidencias/" + grifo.getId() + "/estado";
        mvc.perform(patch(url).header("Authorization", t)).andExpect(jsonPath("$.estado").value("en_proceso"));
        mvc.perform(patch(url).header("Authorization", t)).andExpect(jsonPath("$.estado").value("resuelta"));
        mvc.perform(patch(url).header("Authorization", t))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("INCIDENCIA_RESUELTA"));
        mvc.perform(patch(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content("{\"estado\":\"pendiente\"}"))
                .andExpect(jsonPath("$.estado").value("pendiente"));
    }

    @Test
    void costeDeReparacion_yBorrar() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(patch("/api/incidencias/" + grifo.getId()).header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"costeReparacion\":\"85.50\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.costeReparacion").value(85.50));
        mvc.perform(patch("/api/incidencias/" + grifo.getId()).header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"costeReparacion\":\"-1\"}"))
                .andExpect(status().isBadRequest());
        mvc.perform(delete("/api/incidencias/" + deBea.getId()).header("Authorization", t)).andExpect(status().isNotFound());
        mvc.perform(delete("/api/incidencias/" + grifo.getId()).header("Authorization", t)).andExpect(status().isNoContent());
    }

    @Test
    void inquilino_veYComunicaLasSuyas_peroNoLasGestiona() throws Exception {
        lucia.setUsuario(datos.usuario("lucia@test.com", Rol.INQUILINO));
        String t = token("lucia@test.com");
        mvc.perform(get("/api/incidencias").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1));
        mvc.perform(post("/api/incidencias").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"descripcion\":\"Se ha fundido la bombilla\",\"costeReparacion\":\"999\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.habitacion.id").value(alquilada.getId()))
                // Un inquilino no fija el coste de reparación.
                .andExpect(jsonPath("$.costeReparacion").value(0));
        mvc.perform(patch("/api/incidencias/" + grifo.getId() + "/estado").header("Authorization", t))
                .andExpect(status().isForbidden());
        mvc.perform(delete("/api/incidencias/" + grifo.getId()).header("Authorization", t))
                .andExpect(status().isForbidden());
    }

    @Test
    void detalleDePiso_ingresosPagosYPdf() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(get("/api/pisos/" + pisoAna.getId() + "/ingresos").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(12))
                .andExpect(jsonPath("$[11].importe").value(450.00));
        mvc.perform(get("/api/pagos").param("piso", pisoAna.getId().toString()).header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1));
        byte[] pdf = mvc.perform(get("/api/pisos/" + pisoAna.getId() + "/pdf").header("Authorization", t))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsByteArray();
        assertThat(new String(pdf, 0, 5)).isEqualTo("%PDF-");
        mvc.perform(get("/api/pisos/" + pisoAna.getId() + "/pdf").header("Authorization", token("bea@test.com")))
                .andExpect(status().isNotFound());
    }
}
