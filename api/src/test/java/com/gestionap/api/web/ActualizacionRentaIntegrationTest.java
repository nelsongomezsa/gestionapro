package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.service.IndicesOficiales;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.HashMap;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class ActualizacionRentaIntegrationTest extends IntegrationTest {

    @Autowired IndicesOficiales indices;

    final LocalDate hoy = LocalDate.now();
    Inquilino lucia;
    Contrato nuevo;      // firmado tras la Ley 12/2023: IRAV
    Contrato antiguo;    // anterior: IPC

    @BeforeEach
    void preparar() {
        Usuario ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        datos.usuario("bea@test.com", Rol.PROPIETARIO);
        Piso piso = datos.piso("Calle de Ana 1", datos.ciudad("Madrid"), ana);
        lucia = datos.inquilinoDe(ana, "11111111A");
        // Aniversario dentro de 10 días: ya se puede preparar.
        nuevo = datos.contrato(datos.habitacion(piso, 1, EstadoHabitacion.alquilada), lucia, "500.00",
                hoy.plusDays(10).minusYears(1), hoy.plusYears(2));
        antiguo = datos.contrato(datos.habitacion(piso, 2, EstadoHabitacion.alquilada), datos.inquilinoDe(ana, "22222222B"),
                "400.00", LocalDate.of(2022, 1, 10), hoy.plusYears(1));
        Map<YearMonth, BigDecimal> irav = new HashMap<>();
        Map<YearMonth, BigDecimal> ipc = new HashMap<>();
        for (int i = 0; i < 30; i++) {
            irav.put(YearMonth.from(hoy).minusMonths(i), new BigDecimal("2.54"));
            ipc.put(YearMonth.from(hoy).minusMonths(i), new BigDecimal("4.90"));
        }
        indices.fijar("IRAV", irav);
        indices.fijar("IPC", ipc);
    }

    private String confirmacion(LocalDate fecha, String indice, String pct) throws Exception {
        Map<String, Object> m = new HashMap<>();
        m.put("fechaEfecto", fecha.toString());
        m.put("indice", indice);
        if (pct != null) m.put("porcentaje", pct);
        return json(m);
    }

    @Test
    void propuesta_recomiendaIravParaContratosNuevos_eIpcParaAntiguos() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(get("/api/contratos/" + nuevo.getId() + "/actualizacion-renta").header("Authorization", t))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.debida").value(true))
                .andExpect(jsonPath("$.indice").value("IRAV"))
                .andExpect(jsonPath("$.porcentaje").value(2.54))
                .andExpect(jsonPath("$.rentaNueva").value(512.70))
                .andExpect(jsonPath("$.fuente").value(org.hamcrest.Matchers.containsString("INE")));
        // IPC (4,90 %) por encima del IRAV (2,54 %): se limita al IRAV (LAU art. 18.1).
        mvc.perform(get("/api/contratos/" + antiguo.getId() + "/actualizacion-renta").header("Authorization", t))
                .andExpect(jsonPath("$.indiceRecomendado").value("IPC"))
                .andExpect(jsonPath("$.porcentaje").value(2.54))
                .andExpect(jsonPath("$.limitadoPorIrav").value(true))
                .andExpect(jsonPath("$.rentaNueva").value(410.16));
        // Se puede pedir otro índice.
        mvc.perform(get("/api/contratos/" + antiguo.getId() + "/actualizacion-renta").param("indice", "IRAV").header("Authorization", t))
                .andExpect(jsonPath("$.indice").value("IRAV"))
                .andExpect(jsonPath("$.indiceRecomendado").value("IPC"));
    }

    @Test
    void confirmar_cambiaLaRenta_quedaEnElHistorial_yNoSeRepite() throws Exception {
        String t = token("ana@test.com");
        LocalDate fecha = nuevo.getFechaInicio().plusYears(1);
        String url = "/api/contratos/" + nuevo.getId() + "/actualizacion-renta";
        // Aunque la app mande otro porcentaje, con dato del INE manda el INE.
        mvc.perform(post(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(confirmacion(fecha, "IRAV", "9")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.porcentaje").value(2.54))
                .andExpect(jsonPath("$.rentaAnterior").value(500))
                .andExpect(jsonPath("$.rentaNueva").value(512.70));
        mvc.perform(get("/api/contratos/" + nuevo.getId()).header("Authorization", t))
                .andExpect(jsonPath("$.precioMensual").value(512.70));
        mvc.perform(post(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(confirmacion(fecha, "IRAV", null)))
                .andExpect(status().isConflict());
        mvc.perform(get(url).header("Authorization", t)).andExpect(jsonPath("$.debida").value(false));
        mvc.perform(get("/api/contratos/" + nuevo.getId() + "/actualizaciones-renta").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].indice").value("IRAV"));
    }

    @Test
    void confirmar_soloEnUnAniversarioCercano_yPactadoExigePorcentaje() throws Exception {
        String t = token("ana@test.com");
        String url = "/api/contratos/" + antiguo.getId() + "/actualizacion-renta";
        mvc.perform(post(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(confirmacion(antiguo.getFechaInicio().plusYears(1).plusDays(3), "IPC", null)))
                .andExpect(jsonPath("$.codigo").value("FECHA_ACTUALIZACION_NO_VALIDA"));
        mvc.perform(post(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(confirmacion(antiguo.getFechaInicio().plusYears(10), "IPC", null)))
                .andExpect(jsonPath("$.codigo").value("FECHA_ACTUALIZACION_NO_VALIDA"));
        LocalDate pasada = antiguo.getFechaInicio().plusYears(hoy.getYear() - 2022 - (hoy.getDayOfYear() < 10 ? 1 : 0));
        mvc.perform(post(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(confirmacion(pasada, "PACTADO", null)))
                .andExpect(jsonPath("$.codigo").value("FALTA_PORCENTAJE"));
        // Pactado por encima del IRAV: se queda en el IRAV.
        mvc.perform(post(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(confirmacion(pasada, "PACTADO", "5")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.porcentaje").value(2.54))
                .andExpect(jsonPath("$.rentaNueva").value(410.16));
    }

    @Test
    void sePuedeAplicarMenosQueElMaximo_nuncaMas() throws Exception {
        String t = token("ana@test.com");
        String url = "/api/contratos/" + nuevo.getId() + "/actualizacion-renta";
        mvc.perform(post(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(confirmacion(nuevo.getFechaInicio().plusYears(1), "IRAV", "1.5")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.porcentaje").value(1.5))
                .andExpect(jsonPath("$.rentaNueva").value(507.50))
                .andExpect(jsonPath("$.fuente").value(org.hamcrest.Matchers.containsString("Por debajo del máximo")));
    }

    @Test
    void sinAniversarioAntesDelFin_noHayPropuesta() throws Exception {
        nuevo.setFechaFin(nuevo.getFechaInicio().plusMonths(11));
        mvc.perform(get("/api/contratos/" + nuevo.getId() + "/actualizacion-renta").header("Authorization", token("ana@test.com")))
                .andExpect(jsonPath("$.debida").value(false))
                .andExpect(jsonPath("$.fechaEfecto").doesNotExist());
    }

    @Test
    void sinDatoDelIne_seUsaElPorcentajeDelPropietario() throws Exception {
        indices.fijar("IRAV", Map.of());
        String t = token("ana@test.com");
        String url = "/api/contratos/" + nuevo.getId() + "/actualizacion-renta";
        mvc.perform(get(url).header("Authorization", t))
                .andExpect(jsonPath("$.porcentaje").doesNotExist())
                .andExpect(jsonPath("$.rentaNueva").doesNotExist());
        mvc.perform(post(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(confirmacion(nuevo.getFechaInicio().plusYears(1), "IRAV", "2.5")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.rentaNueva").value(512.50))
                .andExpect(jsonPath("$.fuente").value(org.hamcrest.Matchers.containsString("introducido por el propietario")));
    }

    @Test
    void acceso_inquiliNoVeLaPropuestaNiConfirma_peroSiElHistorial_yOtroPropietarioNada() throws Exception {
        lucia.setUsuario(datos.usuario("lucia@test.com", Rol.INQUILINO));
        String tl = token("lucia@test.com");
        String url = "/api/contratos/" + nuevo.getId();
        mvc.perform(get(url + "/actualizacion-renta").header("Authorization", tl)).andExpect(status().isForbidden());
        mvc.perform(post(url + "/actualizacion-renta").header("Authorization", tl).contentType(MediaType.APPLICATION_JSON)
                .content(confirmacion(nuevo.getFechaInicio().plusYears(1), "IRAV", null))).andExpect(status().isForbidden());
        mvc.perform(get(url + "/actualizaciones-renta").header("Authorization", tl)).andExpect(status().isOk());
        String tb = token("bea@test.com");
        mvc.perform(get(url + "/actualizacion-renta").header("Authorization", tb)).andExpect(status().isNotFound());
        mvc.perform(get(url + "/actualizaciones-renta").header("Authorization", tb)).andExpect(status().isNotFound());
    }
}
