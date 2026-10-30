package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.LocalDate;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class ReciboIntegrationTest extends IntegrationTest {

    final LocalDate hoy = LocalDate.now();
    Inquilino lucia;
    Contrato deLucia;
    Contrato deBea;
    Pago delEscritorio;
    Pago deBeaPago;

    @BeforeEach
    void preparar() {
        Ciudad madrid = datos.ciudad("Madrid");
        Usuario ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Usuario bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        Habitacion h1 = datos.habitacion(datos.piso("Calle de Ana 1", madrid, ana), 1, EstadoHabitacion.alquilada);
        Habitacion h2 = datos.habitacion(datos.piso("Calle de Bea 2", madrid, bea), 1, EstadoHabitacion.alquilada);
        lucia = datos.inquilinoDe(ana, "11111111A");
        deLucia = datos.contrato(h1, lucia, "450.00", hoy.minusMonths(3), hoy.plusMonths(9));
        deBea = datos.contrato(h2, datos.inquilinoDe(bea, "22222222B"), "400.00", hoy.minusMonths(3), hoy.plusMonths(9));
        // Pagos creados "desde el escritorio": sin recibo hasta que se pide.
        delEscritorio = datos.pago(deLucia, "450.00", hoy.minusMonths(1));
        deBeaPago = datos.pago(deBea, "400.00", hoy);
    }

    private String registrar(String token) throws Exception {
        var res = mvc.perform(post("/api/pagos").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("idContrato", deLucia.getId(), "cantidad", "450", "metodoPago", "transferencia",
                                "fechaPago", hoy.toString()))))
                .andExpect(status().isCreated()).andReturn();
        return com.jayway.jsonpath.JsonPath.read(res.getResponse().getContentAsString(), "$.recibo");
    }

    @Test
    void registrarPago_numeraLosRecibosPorPropietarioYAnio() throws Exception {
        String t = token("ana@test.com");
        assertThat(registrar(t)).isEqualTo(hoy.getYear() + "-0001");
        assertThat(registrar(t)).isEqualTo(hoy.getYear() + "-0002");
        // Otra propietaria empieza su propia serie.
        mvc.perform(get("/api/pagos/" + deBeaPago.getId() + "/recibo").header("Authorization", token("bea@test.com")))
                .andExpect(status().isOk());
        mvc.perform(get("/api/pagos").header("Authorization", token("bea@test.com")))
                .andExpect(jsonPath("$[0].recibo").value(hoy.getYear() + "-0001"));
    }

    @Test
    void pagoDelEscritorio_recibeNumeroAlPedirSuRecibo_yLoConserva() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(get("/api/pagos").header("Authorization", t))
                .andExpect(jsonPath("$[0].recibo").doesNotExist());
        var pdf = mvc.perform(get("/api/pagos/" + delEscritorio.getId() + "/recibo").header("Authorization", t))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_PDF))
                .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.containsString("Recibo-")))
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(new String(pdf, 0, 5)).isEqualTo("%PDF-");
        String codigo = delEscritorio.getFechaPago().getYear() + "-0001";
        mvc.perform(get("/api/pagos").header("Authorization", t))
                .andExpect(jsonPath("$[0].recibo").value(codigo));
        // Pedirlo otra vez no cambia el número.
        mvc.perform(get("/api/pagos/" + delEscritorio.getId() + "/recibo").header("Authorization", t))
                .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.containsString(codigo)));
    }

    @Test
    void recibo_soloLoVenElPropietarioElAdminYSuInquilino() throws Exception {
        String url = "/api/pagos/" + delEscritorio.getId() + "/recibo";
        mvc.perform(get(url).header("Authorization", token("bea@test.com"))).andExpect(status().isNotFound());
        datos.usuario("admin@test.com", Rol.ADMIN);
        mvc.perform(get(url).header("Authorization", token("admin@test.com"))).andExpect(status().isOk());

        lucia.setUsuario(datos.usuario("lucia@test.com", Rol.INQUILINO));
        String tl = token("lucia@test.com");
        mvc.perform(get(url).header("Authorization", tl)).andExpect(status().isOk());
        mvc.perform(get("/api/pagos/" + deBeaPago.getId() + "/recibo").header("Authorization", tl))
                .andExpect(status().isNotFound());
        mvc.perform(post(url + "/enviar").header("Authorization", tl)).andExpect(status().isForbidden());
    }

    @Test
    void enviarRecibo_sinEmailConfigurado_devuelveNoEnviado_ySinEmailDelInquilino409() throws Exception {
        String url = "/api/pagos/" + delEscritorio.getId() + "/recibo/enviar";
        mvc.perform(post(url).header("Authorization", token("ana@test.com")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("INQUILINO_SIN_EMAIL"));
        lucia.setEmail("lucia@correo.test");
        mvc.perform(post("/api/pagos/" + delEscritorio.getId() + "/recibo/enviar").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enviado").value(false));
    }
}
