package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.repository.HabitacionRepository;
import com.gestionap.api.repository.PisoRepository;
import com.gestionap.api.repository.ReciboRepository;
import com.itextpdf.kernel.pdf.PdfDocument;
import com.itextpdf.kernel.pdf.PdfReader;
import com.itextpdf.kernel.pdf.canvas.parser.PdfTextExtractor;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** V12: garajes y trasteros (tipos de inmueble y unidad, IVA por contrato, filtros y textos). */
class GarajesTrasterosIntegrationTest extends IntegrationTest {

    @Autowired PisoRepository pisos;
    @Autowired HabitacionRepository habitaciones;
    @Autowired ReciboRepository recibos;

    final LocalDate hoy = LocalDate.now();
    Ciudad madrid;
    Usuario ana;
    Piso vivienda;
    Piso garaje;
    Habitacion habitacion;
    Habitacion plaza;
    Inquilino lucia;

    @BeforeEach
    void preparar() {
        madrid = datos.ciudad("Madrid");
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        datos.usuario("bea@test.com", Rol.PROPIETARIO);
        vivienda = datos.piso("Calle Mayor 1", madrid, ana);
        habitacion = datos.habitacion(vivienda, 1, EstadoHabitacion.disponible);
        garaje = datos.piso("Garaje Sol", madrid, ana);
        garaje.setTipo(TipoInmueble.garajes);
        plaza = datos.habitacion(garaje, 1, EstadoHabitacion.disponible);
        plaza.setTipo(TipoUnidad.plaza);
        plaza.setPrecio(new BigDecimal("121.00"));
        lucia = datos.inquilinoDe(ana, "11111111A");
    }

    private Map<String, Object> inmueble(String tipo, int unidades, List<Map<String, Object>> lista) {
        Map<String, Object> m = new HashMap<>();
        m.put("direccion", "Calle Nueva 3");
        m.put("numeroHabitaciones", unidades);
        m.put("idCiudad", madrid.getId());
        if (tipo != null) m.put("tipo", tipo);
        if (lista != null) m.put("habitaciones", lista);
        return m;
    }

    private static Map<String, Object> unidad(int numero, Object... extra) {
        Map<String, Object> m = new HashMap<>(Map.of("numero", numero, "precio", "90"));
        for (int i = 0; i < extra.length; i += 2) m.put((String) extra[i], extra[i + 1]);
        return m;
    }

    private String contrato(Habitacion h, Map<String, Object> extra, int esperado) throws Exception {
        Map<String, Object> m = new HashMap<>(Map.of("idHabitacion", h.getId(), "idInquilino", lucia.getId(),
                "fechaInicio", hoy.minusDays(10).toString(), "fechaFin", hoy.plusMonths(3).toString(), "precioMensual", "121.00"));
        m.putAll(extra);
        return mvc.perform(post("/api/contratos").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(m)))
                .andExpect(status().is(esperado)).andReturn().getResponse().getContentAsString();
    }

    private static String texto(byte[] pdf) throws Exception {
        try (PdfDocument doc = new PdfDocument(new PdfReader(new ByteArrayInputStream(pdf)))) {
            StringBuilder sb = new StringBuilder();
            for (int i = 1; i <= doc.getNumberOfPages(); i++) sb.append(PdfTextExtractor.getTextFromPage(doc.getPage(i))).append('\n');
            return sb.toString();
        }
    }

    // ── Alta de inmuebles y unidades ─────────────────────────────

    @Test
    void altaDeGaraje_creaPlazasConSusDatos() throws Exception {
        var lista = List.of(unidad(1, "metros", "12.5", "planta", "-1", "vehiculo", "coche"),
                unidad(2, "vehiculo", "moto"), unidad(3, "tipo", "trastero", "metros", "4"));
        mvc.perform(post("/api/pisos").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(inmueble("garajes", 3, lista))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.tipo").value("garajes"))
                .andExpect(jsonPath("$.ocupacion.total").value(3));
        Piso p = pisos.findAll().stream().filter(x -> x.getDireccion().equals("Calle Nueva 3")).findFirst().orElseThrow();
        var unidades = habitaciones.findByPisoId(p.getId());
        assertThat(unidades).extracting(Habitacion::getTipo)
                .containsExactlyInAnyOrder(TipoUnidad.plaza, TipoUnidad.plaza, TipoUnidad.trastero);
        Habitacion primera = unidades.stream().filter(h -> h.getNumero() == 1).findFirst().orElseThrow();
        assertThat(primera.getMetros()).isEqualByComparingTo("12.5");
        assertThat(primera.getPlanta()).isEqualTo("-1");
        assertThat(primera.getVehiculo()).isEqualTo(Vehiculo.coche);
    }

    @Test
    void sinTipo_esUnaViviendaConHabitaciones_comoSiempre() throws Exception {
        mvc.perform(post("/api/pisos").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(inmueble(null, 1, List.of(unidad(1))))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.tipo").value("vivienda"));
        mvc.perform(get("/api/habitaciones?piso=" + vivienda.getId()).header("Authorization", token("ana@test.com")))
                .andExpect(jsonPath("$[0].tipo").value("habitacion"))
                .andExpect(jsonPath("$[0].piso.tipo").value("vivienda"));
    }

    @Test
    void masDe50Unidades_soloEnGarajesYTrasteros() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(post("/api/pisos").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(inmueble("vivienda", 60, null))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("HABITACIONES_INVALIDAS"));
        List<Map<String, Object>> lista = new ArrayList<>();
        for (int i = 1; i <= 120; i++) lista.add(unidad(i));
        mvc.perform(post("/api/pisos").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(inmueble("trasteros", 120, lista))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.ocupacion.total").value(120));
        mvc.perform(post("/api/pisos").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(inmueble("garajes", 501, null))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void unidadQueNoCabeEnElInmueble_400() throws Exception {
        String t = token("ana@test.com");
        // Un trastero no cabe en una vivienda, ni una plaza en un edificio de trasteros.
        mvc.perform(post("/api/pisos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(inmueble("vivienda", 1, List.of(unidad(1, "tipo", "trastero"))))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("TIPO_UNIDAD_NO_VALIDO"));
        mvc.perform(post("/api/pisos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(inmueble("trasteros", 1, List.of(unidad(1, "tipo", "plaza"))))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("TIPO_UNIDAD_NO_VALIDO"));
        // Habitación nueva en un garaje.
        mvc.perform(post("/api/habitaciones").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idPiso", garaje.getId(), "numero", 7, "precio", "80", "tipo", "habitacion"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("TIPO_UNIDAD_NO_VALIDO"));
    }

    @Test
    void cocheOMoto_soloEnPlazas_yPlantaSinCaracteresRaros() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(post("/api/habitaciones").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idPiso", garaje.getId(), "numero", 8, "precio", "60", "tipo", "trastero",
                                "vehiculo", "coche"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("VEHICULO_NO_VALIDO"));
        mvc.perform(post("/api/habitaciones").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idPiso", garaje.getId(), "numero", 8, "precio", "60", "planta", "<script>"))))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/habitaciones").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idPiso", garaje.getId(), "numero", 8, "precio", "60", "metros", "-3"))))
                .andExpect(status().isBadRequest());
        // Sin tipo: la unidad propia del garaje (plaza).
        mvc.perform(post("/api/habitaciones").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idPiso", garaje.getId(), "numero", 8, "precio", "60", "planta", "Sótano 2",
                                "vehiculo", "moto"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.tipo").value("plaza"))
                .andExpect(jsonPath("$.planta").value("Sótano 2"))
                .andExpect(jsonPath("$.vehiculo").value("moto"));
    }

    @Test
    void cambiarElTipo_soloSiSusUnidadesCaben() throws Exception {
        String t = token("ana@test.com");
        Map<String, Object> cambio = new HashMap<>(Map.of("direccion", "Garaje Sol", "numeroHabitaciones", 1,
                "idCiudad", madrid.getId(), "tipo", "vivienda"));
        mvc.perform(put("/api/pisos/" + garaje.getId()).header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(cambio)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("TIPO_INCOMPATIBLE"));
        plaza.setTipo(TipoUnidad.trastero);
        cambio.put("tipo", "trasteros");
        mvc.perform(put("/api/pisos/" + garaje.getId()).header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(cambio)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tipo").value("trasteros"));
    }

    // ── Autorización por propietario ─────────────────────────────

    @Test
    void otroPropietario_noVeNiTocaElGarajeAjeno() throws Exception {
        String bea = token("bea@test.com");
        mvc.perform(get("/api/pisos/" + garaje.getId()).header("Authorization", bea))
                .andExpect(status().isNotFound());
        mvc.perform(post("/api/habitaciones").header("Authorization", bea).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idPiso", garaje.getId(), "numero", 9, "precio", "60"))))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/pagos/resumen?tipo=garajes").header("Authorization", bea))
                .andExpect(jsonPath("$.pendientes", hasSize(0)));
        String c = contrato(plaza, Map.of(), 201);
        int id = com.jayway.jsonpath.JsonPath.read(c, "$.id");
        mvc.perform(put("/api/contratos/" + id + "/iva").header("Authorization", bea)
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("aplicaIva", true))))
                .andExpect(status().isNotFound());
    }

    @Test
    void inquilino_noPuedeCambiarElIva() throws Exception {
        String c = contrato(plaza, Map.of(), 201);
        int id = com.jayway.jsonpath.JsonPath.read(c, "$.id");
        datos.usuario("inq@test.com", Rol.INQUILINO);
        mvc.perform(put("/api/contratos/" + id + "/iva").header("Authorization", token("inq@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("aplicaIva", true))))
                .andExpect(status().isForbidden());
    }

    // ── Contratos con IVA y recibos ──────────────────────────────

    @Test
    void contratoDePlaza_conIva21PorDefecto() throws Exception {
        String c = contrato(plaza, Map.of("aplicaIva", true), 201);
        assertThat((Boolean) com.jayway.jsonpath.JsonPath.read(c, "$.aplicaIva")).isTrue();
        assertThat(com.jayway.jsonpath.JsonPath.<Double>read(c, "$.ivaPct")).isEqualTo(21.0);
        assertThat(com.jayway.jsonpath.JsonPath.<String>read(c, "$.habitacion.tipo")).isEqualTo("plaza");
        // Sin indicar nada: sin IVA.
        Habitacion otra = datos.habitacion(garaje, 2, EstadoHabitacion.disponible);
        otra.setTipo(TipoUnidad.plaza);
        String s = contrato(otra, Map.of(), 201);
        assertThat((Boolean) com.jayway.jsonpath.JsonPath.read(s, "$.aplicaIva")).isFalse();
    }

    @Test
    void ivaEnUnaHabitacion_oPorcentajeFueraDeRango_400() throws Exception {
        contrato(habitacion, Map.of("aplicaIva", true), 400);
        contrato(plaza, Map.of("aplicaIva", true, "ivaPct", "50"), 400);
        contrato(plaza, Map.of("aplicaIva", true, "ivaPct", "-1"), 400);
    }

    @Test
    void reciboConIva_desglosaBaseYCuota_yNoCambiaSiLuegoSeQuitaElIva() throws Exception {
        String c = contrato(plaza, Map.of("aplicaIva", true, "ivaPct", "21"), 201);
        int id = com.jayway.jsonpath.JsonPath.read(c, "$.id");
        String t = token("ana@test.com");
        String pago = mvc.perform(post("/api/pagos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idContrato", id, "cantidad", "121.00", "metodoPago", "transferencia",
                                "fechaPago", hoy.toString()))))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        int idPago = com.jayway.jsonpath.JsonPath.read(pago, "$.id");
        Recibo r = recibos.findByPagoId(idPago).orElseThrow();
        assertThat(r.getBaseImponible()).isEqualByComparingTo("100.00");
        assertThat(r.getCuotaIva()).isEqualByComparingTo("21.00");
        assertThat(r.getIvaPct()).isEqualByComparingTo("21");

        mvc.perform(put("/api/contratos/" + id + "/iva").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("aplicaIva", false))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.aplicaIva").value(false));
        byte[] pdf = mvc.perform(get("/api/pagos/" + idPago + "/recibo").header("Authorization", t))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsByteArray();
        String txt = texto(pdf);
        assertThat(txt).contains("Base imponible").contains("IVA 21 %").contains("plaza 1");
    }

    @Test
    void reciboSinIva_noLlevaDesglose() throws Exception {
        String c = contrato(plaza, Map.of(), 201);
        int id = com.jayway.jsonpath.JsonPath.read(c, "$.id");
        String t = token("ana@test.com");
        String pago = mvc.perform(post("/api/pagos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idContrato", id, "cantidad", "121.00", "metodoPago", "efectivo",
                                "fechaPago", hoy.toString()))))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        int idPago = com.jayway.jsonpath.JsonPath.read(pago, "$.id");
        assertThat(recibos.findByPagoId(idPago).orElseThrow().getBaseImponible()).isNull();
        byte[] pdf = mvc.perform(get("/api/pagos/" + idPago + "/recibo").header("Authorization", t))
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(texto(pdf)).doesNotContain("Base imponible");
    }

    @Test
    void contratoPdfDePlaza_usaSuPlantilla_conIvaYSinFianza() throws Exception {
        plaza.setPlanta("-1");
        String c = contrato(plaza, Map.of("aplicaIva", true), 201);
        int id = com.jayway.jsonpath.JsonPath.read(c, "$.id");
        byte[] pdf = mvc.perform(get("/api/contratos/" + id + "/pdf").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsByteArray();
        String txt = texto(pdf);
        assertThat(txt).contains("DE PLAZA DE GARAJE").contains("IVA incluido").contains("no constituir fianza")
                .contains("planta -1").doesNotContain("HABITACIÓN");
    }

    @Test
    void contratoPdfDeHabitacion_sigueIgual() throws Exception {
        String c = contrato(habitacion, Map.of(), 201);
        int id = com.jayway.jsonpath.JsonPath.read(c, "$.id");
        byte[] pdf = mvc.perform(get("/api/contratos/" + id + "/pdf").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsByteArray();
        assertThat(texto(pdf)).contains("DE HABITACIÓN EN PISO COMPARTIDO");
    }

    // ── Filtros por tipo ─────────────────────────────────────────

    @Test
    void filtrosPorTipo_enCobrosAtrasadosYEstadisticas() throws Exception {
        datos.contrato(habitacion, lucia, "400.00", hoy.minusMonths(3), hoy.plusMonths(9));
        Contrato deLaPlaza = datos.contrato(plaza, datos.inquilinoDe(ana, "22222222B"), "121.00",
                hoy.minusMonths(3), hoy.plusMonths(9));
        datos.pago(deLaPlaza, "121.00", hoy);
        String t = token("ana@test.com");
        mvc.perform(get("/api/pagos/resumen?tipo=garajes").header("Authorization", t))
                .andExpect(jsonPath("$.esperado").value(121.0))
                .andExpect(jsonPath("$.cobrado").value(121.0))
                .andExpect(jsonPath("$.pendientes", hasSize(0)));
        mvc.perform(get("/api/pagos/resumen?tipo=vivienda").header("Authorization", t))
                .andExpect(jsonPath("$.esperado").value(400.0))
                .andExpect(jsonPath("$.pendientes[0].tipoUnidad").value("habitacion"));
        mvc.perform(get("/api/pagos/resumen").header("Authorization", t))
                .andExpect(jsonPath("$.esperado").value(521.0));
        mvc.perform(get("/api/pagos?tipo=vivienda").header("Authorization", t))
                .andExpect(jsonPath("$", hasSize(0)));
        mvc.perform(get("/api/pagos?tipo=garajes").header("Authorization", t))
                .andExpect(jsonPath("$[0].tipoUnidad").value("plaza"));
        mvc.perform(get("/api/pagos/atrasados?tipo=garajes&meses=2").header("Authorization", t))
                .andExpect(jsonPath("$[0].tipoUnidad").value("plaza"));
        mvc.perform(get("/api/pagos/atrasados?tipo=trasteros").header("Authorization", t))
                .andExpect(jsonPath("$", hasSize(0)));
        String desde = hoy.withDayOfMonth(1).toString(), hasta = hoy.toString();
        mvc.perform(get("/api/estadisticas/analisis?desde=" + desde + "&hasta=" + hasta + "&tipo=garajes").header("Authorization", t))
                .andExpect(jsonPath("$.actual.ingresos").value(121.0))
                .andExpect(jsonPath("$.actual.habitaciones").value(1));
        mvc.perform(get("/api/pagos/resumen?tipo=castillos").header("Authorization", t))
                .andExpect(status().isBadRequest());
    }

    // ── Calculadora ──────────────────────────────────────────────

    @Test
    void analisisDeUnaPlaza_guardaElTipo() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(post("/api/analisis-inversion").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("nombre", "Plaza en Chamberí", "entrada", Map.of("comunidad", "Madrid",
                                "precioCompra", 25000, "alquilerMensual", 110, "tipoInmueble", "garajes")))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.entrada.tipoInmueble").value("garajes"));
    }
}
