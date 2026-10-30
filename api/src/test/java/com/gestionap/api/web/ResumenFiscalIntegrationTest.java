package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.repository.PisoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class ResumenFiscalIntegrationTest extends IntegrationTest {

    @Autowired PisoRepository pisos;

    int idPiso;
    String url;

    @BeforeEach
    void preparar() throws Exception {
        Usuario ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        datos.usuario("bea@test.com", Rol.PROPIETARIO);
        Ciudad madrid = datos.ciudad("Madrid");
        Map<String, Object> df = new HashMap<>();
        df.put("precioCompra", 100000);
        df.put("itpPagado", 8000);
        df.put("gastosNotaria", 1000);
        df.put("gastosRegistro", 500);
        df.put("costeMobiliario", 5000);
        df.put("tieneHipoteca", false);
        String t = token("ana@test.com");
        String cuerpo = mvc.perform(post("/api/pisos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("direccion", "Calle Fiscal 1", "numeroHabitaciones", 2, "idCiudad", madrid.getId(),
                                "datosFinancieros", df))))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        idPiso = com.jayway.jsonpath.JsonPath.read(cuerpo, "$.id");
        Piso piso = pisos.findById(idPiso).orElseThrow();
        Habitacion h = datos.habitacion(piso, 1, EstadoHabitacion.alquilada);
        Contrato c = datos.contrato(h, datos.inquilinoDe(ana, "11111111A"), "500.00", LocalDate.of(2025, 1, 1), LocalDate.of(2026, 12, 31));
        datos.pago(c, "500.00", LocalDate.of(2025, 3, 2));
        datos.pago(c, "500.00", LocalDate.of(2025, 4, 2));
        datos.pago(c, "500.00", LocalDate.of(2026, 1, 2));   // de otro año: no cuenta
        gasto(t, "IBI", "400", true);
        gasto(t, "REPARACION", "300", true);
        gasto(t, "INTERESES", "900", true);
        gasto(t, "SEGURO", "120", false);                    // no deducible: no cuenta
        url = "/api/pisos/" + idPiso + "/resumen-fiscal";
    }

    private void gasto(String token, String categoria, String importe, boolean deducible) throws Exception {
        mvc.perform(post("/api/gastos").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idPiso", idPiso, "categoria", categoria, "concepto", categoria, "importe", importe,
                                "fecha", "2025-06-15", "deducible", deducible))))
                .andExpect(status().isCreated());
    }

    @Test
    void calculaIngresosLimiteAmortizacionesYNeto() throws Exception {
        mvc.perform(get(url).param("anio", "2025").param("valorCatastral", "60000").param("valorCatastralConstruccion", "36000")
                        .header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ingresos").value(1000))
                .andExpect(jsonPath("$.numeroPagos").value(2))
                // Intereses + reparación (1.200 €) no pueden superar los ingresos (1.000 €): 200 € para los años siguientes.
                .andExpect(jsonPath("$.gastosConLimiteAplicables").value(1000))
                .andExpect(jsonPath("$.excesoParaAniosSiguientes").value(200))
                .andExpect(jsonPath("$.otrosGastos.length()").value(1))
                // 3 % de 109.500 € × 60 % (construcción según el catastro) = 3 % de 65.700 €.
                .andExpect(jsonPath("$.amortizacionInmueble").value(1971.00))
                .andExpect(jsonPath("$.amortizacionMobiliario").value(500.00))
                .andExpect(jsonPath("$.rendimientoNeto").value(-2871.00));
    }

    @Test
    void sinValorCatastral_noCalculaLaAmortizacionDelInmueble_yLoDice() throws Exception {
        mvc.perform(get(url).param("anio", "2025").header("Authorization", token("ana@test.com")))
                .andExpect(jsonPath("$.amortizacionInmueble").doesNotExist())
                .andExpect(jsonPath("$.baseAmortizacion").value(org.hamcrest.Matchers.containsString("valor catastral")));
    }

    @Test
    void pdfYCsv_yAccesoSoloDelPropietario() throws Exception {
        String t = token("ana@test.com");
        var pdf = mvc.perform(get(url + "/pdf").param("anio", "2025").header("Authorization", t))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsByteArray();
        assertThat(new String(pdf, 0, 5)).isEqualTo("%PDF-");
        var csv = mvc.perform(get(url + "/csv").param("anio", "2025").header("Authorization", t))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsByteArray();
        assertThat(new String(csv, StandardCharsets.UTF_8)).contains("Concepto;Importe").contains("1000,00");
        mvc.perform(get(url).param("anio", "2025").header("Authorization", token("bea@test.com"))).andExpect(status().isNotFound());
    }
}
