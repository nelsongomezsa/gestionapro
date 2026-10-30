package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.repository.HabitacionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.HashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class ContratoPagoIntegrationTest extends IntegrationTest {

    @Autowired HabitacionRepository habitaciones;

    final LocalDate hoy = LocalDate.now();
    Usuario ana;
    Habitacion libre;
    Habitacion alquilada;
    Habitacion deBea;
    Inquilino lucia;
    Inquilino pedro;
    Contrato activoLucia;
    Contrato finalizadoPedro;
    Contrato venceProntoPedro;

    @BeforeEach
    void preparar() {
        Ciudad madrid = datos.ciudad("Madrid");
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Usuario bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        Piso pisoAna = datos.piso("Calle de Ana 1", madrid, ana);
        Piso pisoBea = datos.piso("Calle de Bea 2", madrid, bea);
        libre = datos.habitacion(pisoAna, 1, EstadoHabitacion.disponible);
        alquilada = datos.habitacion(pisoAna, 2, EstadoHabitacion.alquilada);
        Habitacion otra = datos.habitacion(pisoAna, 3, EstadoHabitacion.alquilada);
        deBea = datos.habitacion(pisoBea, 1, EstadoHabitacion.disponible);

        lucia = datos.inquilinoDe(ana, "11111111A");
        pedro = datos.inquilinoDe(ana, "22222222B");
        activoLucia = datos.contrato(alquilada, lucia, "450.00", hoy.minusMonths(3), hoy.plusMonths(9));
        finalizadoPedro = datos.contrato(libre, pedro, "400.00", hoy.minusYears(2), hoy.minusYears(1));
        venceProntoPedro = datos.contrato(otra, pedro, "500.00", hoy.minusMonths(11), hoy.plusDays(5));
        datos.pago(activoLucia, "450.00", hoy);
    }

    private Map<String, Object> contrato(Integer idHabitacion, Integer idInquilino, LocalDate inicio, LocalDate fin) {
        Map<String, Object> m = new HashMap<>();
        m.put("idHabitacion", idHabitacion);
        m.put("idInquilino", idInquilino);
        m.put("fechaInicio", inicio.toString());
        m.put("fechaFin", fin.toString());
        m.put("precioMensual", "430.00");
        return m;
    }

    private Map<String, Object> pago(Integer idContrato, String cantidad, LocalDate fecha) {
        Map<String, Object> m = new HashMap<>();
        m.put("idContrato", idContrato);
        m.put("cantidad", cantidad);
        m.put("metodoPago", "efectivo");
        m.put("fechaPago", fecha.toString());
        return m;
    }

    // ── Contratos ──

    @Test
    void lista_conFiltrosYNivelDeVencimiento() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(get("/api/contratos").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(3));
        mvc.perform(get("/api/contratos").param("filtro", "ACTIVOS").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(2));
        mvc.perform(get("/api/contratos").param("filtro", "FINALIZADOS").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].vencimiento").value("VENCIDO"));
        mvc.perform(get("/api/contratos").param("filtro", "POR_VENCER").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].vencimiento").value("CRITICO"))
                .andExpect(jsonPath("$[0].diasRestantes").value(5))
                .andExpect(jsonPath("$[0].inquilino.nombre").value("Ana García 22222222B"));
        mvc.perform(get("/api/contratos").header("Authorization", token("bea@test.com")))
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void crear_reservaLaHabitacion_ySiYaNoEstaLibre_409() throws Exception {
        String t = token("ana@test.com");
        libre.setEstado(EstadoHabitacion.disponible);
        mvc.perform(post("/api/contratos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(contrato(libre.getId(), lucia.getId(), hoy, hoy.plusYears(1)))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.activo").value(true))
                .andExpect(jsonPath("$.habitacion.numero").value(1));
        assertThat(habitaciones.findById(libre.getId()).orElseThrow().getEstado()).isEqualTo(EstadoHabitacion.alquilada);

        mvc.perform(post("/api/contratos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(contrato(libre.getId(), pedro.getId(), hoy, hoy.plusYears(1)))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("HABITACION_NO_DISPONIBLE"));
    }

    @Test
    void crear_validaciones() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(post("/api/contratos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(contrato(libre.getId(), lucia.getId(), hoy, hoy))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("FECHAS_NO_VALIDAS"));
        mvc.perform(post("/api/contratos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(contrato(deBea.getId(), lucia.getId(), hoy, hoy.plusYears(1)))))
                .andExpect(status().isNotFound());
        var otro = datos.inquilinoDe(datos.usuario("carla@test.com", Rol.PROPIETARIO), "33333333C");
        mvc.perform(post("/api/contratos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(contrato(libre.getId(), otro.getId(), hoy, hoy.plusYears(1)))))
                .andExpect(status().isNotFound());
    }

    @Test
    void finalizar_liberaLaHabitacion_yNoSeRepite() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(post("/api/contratos/" + activoLucia.getId() + "/finalizar").header("Authorization", t))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fechaFin").value(hoy.toString()));
        assertThat(habitaciones.findById(alquilada.getId()).orElseThrow().getEstado()).isEqualTo(EstadoHabitacion.disponible);

        mvc.perform(post("/api/contratos/" + finalizadoPedro.getId() + "/finalizar").header("Authorization", t))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("CONTRATO_NO_ACTIVO"));
        mvc.perform(post("/api/contratos/" + activoLucia.getId() + "/finalizar").header("Authorization", token("bea@test.com")))
                .andExpect(status().isNotFound());
    }

    @Test
    void inquilino_soloVeLoSuyo_yNoPuedeCrearNiFinalizar() throws Exception {
        var cuenta = datos.usuario("lucia@test.com", Rol.INQUILINO);
        lucia.setUsuario(cuenta);
        String t = token("lucia@test.com");
        mvc.perform(get("/api/contratos").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].id").value(activoLucia.getId()));
        mvc.perform(get("/api/contratos/" + venceProntoPedro.getId()).header("Authorization", t))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/pagos").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1));
        mvc.perform(post("/api/contratos/" + activoLucia.getId() + "/finalizar").header("Authorization", t))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/pagos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(pago(activoLucia.getId(), "450", hoy))))
                .andExpect(status().isForbidden());
    }

    @Test
    void inquilinoSinFichaEnlazada_noVeNada() throws Exception {
        datos.usuario("suelto@test.com", Rol.INQUILINO);
        mvc.perform(get("/api/contratos").header("Authorization", token("suelto@test.com")))
                .andExpect(jsonPath("$.length()").value(0));
    }

    // ── Pagos ──

    @Test
    void registrarYBorrarPago() throws Exception {
        String t = token("ana@test.com");
        String cuerpo = mvc.perform(post("/api/pagos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(pago(venceProntoPedro.getId(), "500.00", hoy))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.metodoPago").value("efectivo"))
                .andExpect(jsonPath("$.inquilino.nombre").value("Ana García 22222222B"))
                .andReturn().getResponse().getContentAsString();
        int id = leer(cuerpo).get("id").asInt();

        mvc.perform(delete("/api/pagos/" + id).header("Authorization", token("bea@test.com")))
                .andExpect(status().isNotFound());
        mvc.perform(delete("/api/pagos/" + id).header("Authorization", t))
                .andExpect(status().isNoContent());
    }

    @Test
    void pago_reglas() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(post("/api/pagos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(pago(activoLucia.getId(), "0", hoy.plusDays(1)))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errores.length()").value(2));
        mvc.perform(post("/api/pagos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(pago(finalizadoPedro.getId(), "400", hoy))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("CONTRATO_NO_ACTIVO"));
    }

    @Test
    void lista_porMesYPorInquilino() throws Exception {
        datos.pago(venceProntoPedro, "500.00", hoy.minusMonths(1).withDayOfMonth(1));
        String t = token("ana@test.com");
        mvc.perform(get("/api/pagos").param("mes", YearMonth.from(hoy).toString()).header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1));
        mvc.perform(get("/api/pagos").param("inquilino", pedro.getId().toString()).header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].cantidad").value(500.00));
        mvc.perform(get("/api/pagos").param("mes", "octubre").header("Authorization", t))
                .andExpect(status().isBadRequest());
    }

    @Test
    void resumenDelMes_esperadoCobradoYPendientes() throws Exception {
        mvc.perform(get("/api/pagos/resumen").param("mes", YearMonth.from(hoy).toString()).header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.esperado").value(950.00))
                .andExpect(jsonPath("$.cobrado").value(450.00))
                .andExpect(jsonPath("$.pendiente").value(500.00))
                .andExpect(jsonPath("$.numeroPagos").value(1))
                .andExpect(jsonPath("$.pendientes.length()").value(1))
                .andExpect(jsonPath("$.pendientes[0].idContrato").value(venceProntoPedro.getId()))
                .andExpect(jsonPath("$.nombreMes").isString());
    }
}
