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
    @Autowired com.gestionap.api.repository.HabitacionRepository habitacionesRepo;

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
    void borrar_sinHistorial_borraTambienSusHabitaciones() throws Exception {
        String t = token("ana@test.com");
        var otro = datos.piso("Calle Con Habitaciones", madrid, ana);
        datos.habitacion(otro, 1, EstadoHabitacion.disponible);
        datos.habitacion(otro, 2, EstadoHabitacion.disponible);
        mvc.perform(delete("/api/pisos/" + otro.getId()).header("Authorization", t))
                .andExpect(status().isNoContent());
        mvc.perform(get("/api/pisos/" + otro.getId()).header("Authorization", t)).andExpect(status().isNotFound());
        org.assertj.core.api.Assertions.assertThat(habitacionesRepo.findByPisoId(otro.getId())).isEmpty();
    }

    @Test
    void borrar_conContratoActivo_conHistorial_oConGastos_409ExplicandoPorque() throws Exception {
        String t = token("ana@test.com");
        var activo = datos.piso("Con contrato activo", madrid, ana);
        datos.contratoActivo(datos.habitacion(activo, 1, EstadoHabitacion.alquilada), datos.inquilinoDe(ana, "11111111A"), "400.00");
        mvc.perform(delete("/api/pisos/" + activo.getId()).header("Authorization", t))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("PISO_CON_CONTRATOS_ACTIVOS"))
                .andExpect(jsonPath("$.mensaje").value(org.hamcrest.Matchers.containsString("1 contrato activo")));

        var pasado = datos.piso("Con contrato pasado", madrid, ana);
        datos.contrato(datos.habitacion(pasado, 1, EstadoHabitacion.disponible), datos.inquilinoDe(ana, "22222222B"), "400.00",
                java.time.LocalDate.now().minusYears(2), java.time.LocalDate.now().minusYears(1));
        mvc.perform(delete("/api/pisos/" + pasado.getId()).header("Authorization", t))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("PISO_CON_HISTORIAL"));

        var conGastos = datos.piso("Con gastos", madrid, ana);
        mvc.perform(post("/api/gastos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idPiso", conGastos.getId(), "categoria", "IBI", "concepto", "IBI",
                                "importe", "300.00", "fecha", java.time.LocalDate.now().toString()))))
                .andExpect(status().isCreated());
        mvc.perform(delete("/api/pisos/" + conGastos.getId()).header("Authorization", t))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("PISO_CON_GASTOS"));

        // De otro propietario: 404; inquilino: 403.
        mvc.perform(delete("/api/pisos/" + pisoBea.getId()).header("Authorization", t)).andExpect(status().isNotFound());
        datos.usuario("inq@test.com", Rol.INQUILINO);
        mvc.perform(delete("/api/pisos/" + pisoAna.getId()).header("Authorization", token("inq@test.com")))
                .andExpect(status().isForbidden());
    }

    @Test
    void crear_conSusHabitaciones_enUnaSolaOperacion() throws Exception {
        String t = token("ana@test.com");
        var req = pisoBasico("Calle Nueva 5, 1º");
        req.put("numeroHabitaciones", 2);
        req.put("habitaciones", java.util.List.of(Map.of("numero", 1, "precio", "450.00"), Map.of("numero", 2, "precio", "500.00")));
        String cuerpo = mvc.perform(post("/api/pisos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(json(req)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.ocupacion.total").value(2))
                .andExpect(jsonPath("$.ocupacion.disponibles").value(2))
                .andReturn().getResponse().getContentAsString();
        int id = leer(cuerpo).get("id").asInt();
        mvc.perform(get("/api/habitaciones").param("piso", String.valueOf(id)).header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[1].precio").value(500.00));
        // Aparece en Inicio (ocupación de la cartera).
        mvc.perform(get("/api/dashboard").header("Authorization", t))
                .andExpect(jsonPath("$.ocupacion.habitaciones").value(2));
    }

    @Test
    void crear_habitacionesInvalidas_400_ySinCrearNada() throws Exception {
        String t = token("ana@test.com");
        long antes = pisos.count();
        var distintas = pisoBasico("Calle Mal 1");
        distintas.put("numeroHabitaciones", 2);
        distintas.put("habitaciones", java.util.List.of(Map.of("numero", 1, "precio", "450.00")));
        var repetidas = pisoBasico("Calle Mal 2");
        repetidas.put("numeroHabitaciones", 2);
        repetidas.put("habitaciones", java.util.List.of(Map.of("numero", 1, "precio", "450.00"), Map.of("numero", 1, "precio", "300.00")));
        var sinPrecio = pisoBasico("Calle Mal 3");
        sinPrecio.put("numeroHabitaciones", 1);
        sinPrecio.put("habitaciones", java.util.List.of(Map.of("numero", 1, "precio", "0")));
        for (var r : java.util.List.of(distintas, repetidas, sinPrecio)) {
            mvc.perform(post("/api/pisos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(json(r)))
                    .andExpect(status().isBadRequest());
        }
        org.assertj.core.api.Assertions.assertThat(pisos.count()).isEqualTo(antes);
        datos.usuario("inq@test.com", Rol.INQUILINO);
        mvc.perform(post("/api/pisos").header("Authorization", token("inq@test.com")).contentType(MediaType.APPLICATION_JSON)
                .content(json(pisoBasico("Calle Inquilino")))).andExpect(status().isForbidden());
    }

    @Test
    void ciudades_listarYDarDeAlta_sinDuplicar() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(get("/api/ciudades").header("Authorization", t))
                .andExpect(status().isOk()).andExpect(jsonPath("$[0].nombre").value("Madrid"));
        mvc.perform(post("/api/ciudades").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("nombre", "  málaga "))))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.nombre").value("Málaga"));
        mvc.perform(post("/api/ciudades").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("nombre", "MALAGA"))))
                .andExpect(status().isOk()).andExpect(jsonPath("$.nombre").value("Málaga"));
        mvc.perform(post("/api/ciudades").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("nombre", "<script>")))).andExpect(status().isBadRequest());
        mvc.perform(post("/api/ciudades").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("nombre", "x")))).andExpect(status().isBadRequest());
        datos.usuario("inq@test.com", Rol.INQUILINO);
        mvc.perform(get("/api/ciudades").header("Authorization", token("inq@test.com"))).andExpect(status().isForbidden());
    }

    private Map<String, Object> pisoBasico(String direccion) {
        Map<String, Object> m = new HashMap<>();
        m.put("direccion", direccion);
        m.put("numeroHabitaciones", 3);
        m.put("idCiudad", madrid.getId());
        return m;
    }
}
