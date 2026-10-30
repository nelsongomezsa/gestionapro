package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class FianzaIntegrationTest extends IntegrationTest {

    final LocalDate hoy = LocalDate.now();
    Inquilino lucia;
    Contrato contrato;
    String url;

    @BeforeEach
    void preparar() {
        Ciudad madrid = datos.ciudad("Madrid");
        Usuario ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        datos.usuario("bea@test.com", Rol.PROPIETARIO);
        Habitacion h = datos.habitacion(datos.piso("Calle de Ana 1", madrid, ana), 1, EstadoHabitacion.alquilada);
        lucia = datos.inquilinoDe(ana, "11111111A");
        contrato = datos.contrato(h, lucia, "450.00", hoy.minusMonths(2), hoy.plusMonths(10));
        url = "/api/contratos/" + contrato.getId() + "/fianza";
    }

    private String fianza(String importe, LocalDate deposito) throws Exception {
        Map<String, Object> m = new HashMap<>();
        m.put("importe", importe);
        m.put("fechaCobro", hoy.minusMonths(2).toString());
        if (deposito != null) {
            m.put("fechaDeposito", deposito.toString());
            m.put("organismoDeposito", "Agencia de Vivienda Social");
        }
        return json(m);
    }

    private String devolucion(LocalDate fecha, String importe, String motivo) throws Exception {
        Map<String, Object> m = new HashMap<>();
        m.put("fechaDevolucion", fecha.toString());
        m.put("importeDevuelto", importe);
        if (motivo != null) m.put("motivoRetencion", motivo);
        return json(m);
    }

    private void guardar(String cuerpo) throws Exception {
        mvc.perform(put(url).header("Authorization", token("ana@test.com")).contentType(MediaType.APPLICATION_JSON).content(cuerpo))
                .andExpect(status().isOk());
    }

    @Test
    void crear_depositar_yListarConElTotalPorDevolver() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(get(url).header("Authorization", t)).andExpect(status().isNotFound());
        mvc.perform(put(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(fianza("900.00", null)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.estado").value("SIN_DEPOSITAR"))
                .andExpect(jsonPath("$.pendienteDevolver").value(900));
        mvc.perform(put(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(fianza("900.00", hoy)))
                .andExpect(jsonPath("$.estado").value("DEPOSITADA"))
                .andExpect(jsonPath("$.organismoDeposito").value("Agencia de Vivienda Social"));
        mvc.perform(get("/api/fianzas").header("Authorization", t))
                .andExpect(jsonPath("$.fianzas.length()").value(1))
                .andExpect(jsonPath("$.fianzas[0].numeroHabitacion").value(1))
                .andExpect(jsonPath("$.totalPendienteDevolver").value(900));
        // Depósito anterior al cobro: no.
        mvc.perform(put(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(fianza("900.00", hoy.minusMonths(3))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("FECHA_DEPOSITO_NO_VALIDA"));
    }

    @Test
    void propietarioAjeno_noLaVeNiLaToca() throws Exception {
        guardar(fianza("900.00", null));
        String tb = token("bea@test.com");
        mvc.perform(get(url).header("Authorization", tb)).andExpect(status().isNotFound());
        mvc.perform(put(url).header("Authorization", tb).contentType(MediaType.APPLICATION_JSON).content(fianza("1", null)))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/fianzas").header("Authorization", tb))
                .andExpect(jsonPath("$.fianzas.length()").value(0))
                .andExpect(jsonPath("$.totalPendienteDevolver").value(0));
    }

    @Test
    void inquilino_veLaSuya_yNoPuedeModificarla() throws Exception {
        guardar(fianza("900.00", null));
        lucia.setUsuario(datos.usuario("lucia@test.com", Rol.INQUILINO));
        String t = token("lucia@test.com");
        mvc.perform(get(url).header("Authorization", t)).andExpect(jsonPath("$.importe").value(900));
        mvc.perform(get("/api/fianzas").header("Authorization", t)).andExpect(jsonPath("$.fianzas.length()").value(1));
        mvc.perform(put(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(fianza("1", null)))
                .andExpect(status().isForbidden());
        mvc.perform(post(url + "/devolucion").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(devolucion(hoy, "900", null)))
                .andExpect(status().isForbidden());
    }

    @Test
    void devolucion_parcialExigeMotivo_yLoRetenidoNoQuedaPorDevolver() throws Exception {
        guardar(fianza("900.00", hoy.minusMonths(1)));
        String t = token("ana@test.com");
        String dev = url + "/devolucion";
        mvc.perform(post(dev).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(devolucion(hoy, "1000", null)))
                .andExpect(jsonPath("$.codigo").value("IMPORTE_DEVOLUCION_NO_VALIDO"));
        mvc.perform(post(dev).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(devolucion(hoy, "800", " ")))
                .andExpect(jsonPath("$.codigo").value("MOTIVO_RETENCION_OBLIGATORIO"));
        mvc.perform(post(dev).header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(devolucion(hoy.minusMonths(3), "900", null)))
                .andExpect(jsonPath("$.codigo").value("FECHA_DEVOLUCION_NO_VALIDA"));
        mvc.perform(post(dev).header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(devolucion(hoy, "800", "Pintura de la pared")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.estado").value("DEVUELTA_PARCIAL"))
                .andExpect(jsonPath("$.retenido").value(100))
                .andExpect(jsonPath("$.pendienteDevolver").value(0));
        mvc.perform(get("/api/fianzas").header("Authorization", t)).andExpect(jsonPath("$.totalPendienteDevolver").value(0));
        // Ya devuelta: ni otra devolución ni cambiar el importe (sí el resto de datos).
        mvc.perform(post(dev).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(devolucion(hoy, "900", null)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("FIANZA_YA_DEVUELTA"));
        mvc.perform(put(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(fianza("1000", null)))
                .andExpect(status().isConflict());
        mvc.perform(put(url).header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content(fianza("900.00", null)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.retenido").value(100));
    }
}
