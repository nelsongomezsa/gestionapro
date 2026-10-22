package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.repository.PisoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.util.HashMap;
import java.util.Map;

import static org.hamcrest.Matchers.closeTo;
import static org.hamcrest.Matchers.matchesPattern;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class PisoIntegrationTest extends IntegrationTest {

    @Autowired PisoRepository pisos;

    Ciudad madrid;
    Usuario ana;
    Usuario bea;
    Piso pisoAna;
    Piso pisoBea;

    @BeforeEach
    void preparar() {
        madrid = datos.ciudad("Madrid");
        datos.usuario("admin@test.com", Rol.ADMIN);
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        pisoAna = datos.piso("Calle de Ana 1", madrid, ana);
        pisoBea = datos.piso("Calle de Bea 2", madrid, bea);
    }

    @Test
    void propietario_soloVeSusPisos() throws Exception {
        mvc.perform(get("/api/pisos").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].direccion").value("Calle de Ana 1"));
    }

    @Test
    void propietario_pisoDeOtro_es404ParaNoRevelarQueExiste() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(get("/api/pisos/" + pisoBea.getId()).header("Authorization", t))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.codigo").value("NO_ENCONTRADO"));
        mvc.perform(put("/api/pisos/" + pisoBea.getId()).header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(pisoBasico("Hackeado"))))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/pisos/" + pisoBea.getId()).header("Authorization", t))
                .andExpect(status().isNotFound());
    }

    @Test
    void admin_veTodosLosPisos() throws Exception {
        mvc.perform(get("/api/pisos").header("Authorization", token("admin@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));
    }

    @Test
    void inquilino_noPuedeUsarPisos_403EnJson() throws Exception {
        datos.usuario("inq@test.com", Rol.INQUILINO);

        mvc.perform(get("/api/pisos").header("Authorization", token("inq@test.com")))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.codigo").value("ACCESO_DENEGADO"));
    }

    @Test
    void ocupacionEIngresos_salenDeHabitacionesYContratosActivos() throws Exception {
        var h1 = datos.habitacion(pisoAna, 1, EstadoHabitacion.alquilada);
        var h2 = datos.habitacion(pisoAna, 2, EstadoHabitacion.alquilada);
        datos.habitacion(pisoAna, 3, EstadoHabitacion.disponible);
        datos.contratoActivo(h1, datos.inquilino("11111111A", null), "450.00");
        datos.contratoActivo(h2, datos.inquilino("22222222B", null), "250.00");

        mvc.perform(get("/api/pisos/" + pisoAna.getId()).header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ocupacion.total").value(3))
                .andExpect(jsonPath("$.ocupacion.alquiladas").value(2))
                .andExpect(jsonPath("$.ocupacion.disponibles").value(1))
                .andExpect(jsonPath("$.ingresosMensuales").value(700.00))
                .andExpect(jsonPath("$.metricas").doesNotExist());
    }

    /**
     * Mismo escenario que CalculadoraFinancieraPisoTest.calcular_escenarioCompletoConHipoteca
     * (valores del escritorio), pero entrando por HTTP: los ingresos (700/mes) vienen de
     * contratos activos y los datos financieros del cuerpo del POST.
     */
    @Test
    void crear_conDatosFinancieros_calculaLasMismasMetricasQueElEscritorio() throws Exception {
        String t = token("ana@test.com");
        Map<String, Object> req = pisoBasico("Calle Nueva 5");
        Map<String, Object> df = new HashMap<>();
        df.put("precioCompra", 100000);
        df.put("itpPagado", 8000);
        df.put("gastosNotaria", 1000);
        df.put("gastosRegistro", 500);
        df.put("tieneHipoteca", true);
        df.put("importeHipoteca", 80000);
        df.put("tipoInteres", 3.0);
        df.put("plazoAnos", 20);
        df.put("gastoIbiAnual", 400);
        df.put("gastoComunidadMensual", 60);
        df.put("gastoSeguroAnual", 150);
        df.put("gastoMantenimientoAnual", 300);
        df.put("valorMercadoActual", 130000);
        req.put("datosFinancieros", df);

        String cuerpo = mvc.perform(post("/api/pisos").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(req)))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", matchesPattern(".*/api/pisos/\\d+")))
                .andExpect(jsonPath("$.idPropietario").value(ana.getId()))
                .andExpect(jsonPath("$.datosFinancieros.cuotaMensualHipoteca").value(443.68))
                .andReturn().getResponse().getContentAsString();
        int id = leer(cuerpo).get("id").asInt();

        var h = datos.habitacion(pisos.findById(id).orElseThrow(), 1, EstadoHabitacion.alquilada);
        datos.contratoActivo(h, datos.inquilino("33333333C", null), "700.00");

        mvc.perform(get("/api/pisos/" + id).header("Authorization", t))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.metricas.inversionTotal").value(109500.00))
                .andExpect(jsonPath("$.metricas.cuotaMensualHipoteca").value(443.68))
                .andExpect(jsonPath("$.metricas.gastosAnuales").value(1570.00))
                .andExpect(jsonPath("$.metricas.rentabilidadBrutaPct").value(closeTo(7.6712, 0.0001)))
                .andExpect(jsonPath("$.metricas.rentabilidadNetaPct").value(closeTo(6.2374, 0.0001)))
                .andExpect(jsonPath("$.metricas.calificacion").value("EXCELENTE"))
                .andExpect(jsonPath("$.metricas.cashFlowMensual").value(125.49))
                .andExpect(jsonPath("$.metricas.cashOnCashPct").value(closeTo(5.1047, 0.0001)))
                .andExpect(jsonPath("$.metricas.capitalPropio").value(29500.00))
                .andExpect(jsonPath("$.metricas.plusvaliaLatente").value(20500.00))
                .andExpect(jsonPath("$.metricas.perAnios").value(13.04))
                .andExpect(jsonPath("$.metricas.rocePct").doesNotExist());
    }

    @Test
    void crear_hipotecaDesmarcada_guardaImporteYCuotaACero() throws Exception {
        Map<String, Object> req = pisoBasico("Calle Contado 3");
        req.put("datosFinancieros", Map.of("precioCompra", 90000, "tieneHipoteca", false,
                "importeHipoteca", 80000, "tipoInteres", 3.0, "plazoAnos", 20));

        mvc.perform(post("/api/pisos").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(req)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.datosFinancieros.importeHipoteca").value(0))
                .andExpect(jsonPath("$.datosFinancieros.cuotaMensualHipoteca").value(0));
    }

    @Test
    void crear_datosInvalidos_es400ConErroresPorCampo() throws Exception {
        Map<String, Object> req = new HashMap<>();
        req.put("direccion", "");
        req.put("numeroHabitaciones", 0);
        req.put("idCiudad", madrid.getId());

        mvc.perform(post("/api/pisos").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(req)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("VALIDACION"))
                .andExpect(jsonPath("$.errores[?(@.campo == 'direccion')]").exists())
                .andExpect(jsonPath("$.errores[?(@.campo == 'numeroHabitaciones')]").exists());
    }

    @Test
    void crear_ciudadInexistente_es400() throws Exception {
        Map<String, Object> req = pisoBasico("Calle X");
        req.put("idCiudad", 999999);

        mvc.perform(post("/api/pisos").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(req)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("CIUDAD_NO_EXISTE"));
    }

    @Test
    void actualizar_sinDatosFinancieros_conservaLosGuardados() throws Exception {
        String t = token("ana@test.com");
        Map<String, Object> req = pisoBasico("Calle Ana 1");
        req.put("datosFinancieros", Map.of("precioCompra", 150000));
        mvc.perform(put("/api/pisos/" + pisoAna.getId()).header("Authorization", t)
                .contentType(MediaType.APPLICATION_JSON).content(json(req))).andExpect(status().isOk());

        mvc.perform(put("/api/pisos/" + pisoAna.getId()).header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(pisoBasico("Calle Ana 1, 2º"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.direccion").value("Calle Ana 1, 2º"))
                .andExpect(jsonPath("$.datosFinancieros.precioCompra").value(150000));
    }

    @Test
    void borrar_pisoSinHabitaciones_204_yConHabitaciones_409() throws Exception {
        String t = token("ana@test.com");
        var otro = datos.piso("Calle Con Habitaciones", madrid, ana);
        datos.habitacion(otro, 1, EstadoHabitacion.disponible);

        mvc.perform(delete("/api/pisos/" + otro.getId()).header("Authorization", t))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("PISO_CON_HABITACIONES"));
        mvc.perform(delete("/api/pisos/" + pisoAna.getId()).header("Authorization", t))
                .andExpect(status().isNoContent());
        mvc.perform(get("/api/pisos/" + pisoAna.getId()).header("Authorization", t))
                .andExpect(status().isNotFound());
    }

    private Map<String, Object> pisoBasico(String direccion) {
        Map<String, Object> m = new HashMap<>();
        m.put("direccion", direccion);
        m.put("numeroHabitaciones", 3);
        m.put("idCiudad", madrid.getId());
        return m;
    }
}
