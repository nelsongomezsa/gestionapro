package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.service.ActividadService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.TextStyle;
import java.util.Locale;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class PanelIntegrationTest extends IntegrationTest {

    @Autowired ActividadService actividadService;
    Usuario ana;

    final LocalDate hoy = LocalDate.now();
    final YearMonth mes = YearMonth.from(hoy);
    Contrato pagado;
    Contrato sinPagar;
    Habitacion enMantenimiento;
    Incidencia antigua;

    @BeforeEach
    void preparar() {
        Ciudad madrid = datos.ciudad("Madrid");
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Usuario bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        Piso piso = datos.piso("Calle de Ana 1", madrid, ana);
        Piso deBea = datos.piso("Calle de Bea 2", madrid, bea);
        Habitacion h1 = datos.habitacion(piso, 1, EstadoHabitacion.alquilada);
        Habitacion h2 = datos.habitacion(piso, 2, EstadoHabitacion.alquilada);
        datos.habitacion(piso, 3, EstadoHabitacion.disponible);
        enMantenimiento = datos.habitacion(piso, 4, EstadoHabitacion.mantenimiento);
        Inquilino lucia = datos.inquilinoDe(ana, "11111111A");
        Inquilino pedro = datos.inquilinoDe(ana, "22222222B");
        pagado = datos.contrato(h1, lucia, "400.00", hoy.minusMonths(6), hoy.plusDays(20));
        sinPagar = datos.contrato(h2, pedro, "600.00", hoy.minusMonths(6), hoy.plusMonths(6));
        datos.pago(pagado, "400.00", hoy.withDayOfMonth(1));
        datos.pago(pagado, "400.00", hoy.minusMonths(1).withDayOfMonth(1));
        datos.pago(sinPagar, "600.00", hoy.minusMonths(1).withDayOfMonth(2));
        antigua = datos.incidencia(h1, lucia, "Grifo que gotea");
        antigua.setFecha(hoy.minusDays(10));

        // Datos de otro propietario: no deben contar en nada de Ana.
        Habitacion hb = datos.habitacion(deBea, 1, EstadoHabitacion.alquilada);
        Contrato cb = datos.contrato(hb, datos.inquilinoDe(bea, "33333333C"), "999.00", hoy.minusMonths(1), hoy.plusDays(3));
        datos.pago(cb, "999.00", hoy.withDayOfMonth(1));
    }

    @Test
    void dashboard_soloConLoDelPropietario() throws Exception {
        String cuerpo = mvc.perform(get("/api/dashboard").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ocupacion.habitaciones").value(4))
                .andExpect(jsonPath("$.ocupacion.alquiladas").value(2))
                .andExpect(jsonPath("$.ocupacion.porcentaje").value(50.0))
                .andExpect(jsonPath("$.ocupacion.salud").value("Ocupación media"))
                .andExpect(jsonPath("$.contratosActivos").value(2))
                .andExpect(jsonPath("$.cobradoMes").value(400.00))
                .andExpect(jsonPath("$.cobradoMesAnterior").value(1000.00))
                .andExpect(jsonPath("$.diaComparado").value(Math.min(hoy.getDayOfMonth(), mes.minusMonths(1).lengthOfMonth())))
                .andExpect(jsonPath("$.alertas[0].mensaje").value(""))
                .andExpect(jsonPath("$.esperadoMes").value(1000.00))
                .andExpect(jsonPath("$.incidenciasPendientes").value(1))
                .andExpect(jsonPath("$.ingresosUltimos6Meses.length()").value(6))
                .andExpect(jsonPath("$.proximosVencimientos.length()").value(1))
                .andExpect(jsonPath("$.proximosVencimientos[0].vencimiento").value("PROXIMO"))
                .andExpect(jsonPath("$.alertas[*].tipo").value(hasItem("CONTRATOS_POR_VENCER")))
                .andExpect(jsonPath("$.alertas[*].tipo").value(hasItem("OCUPACION")))
                .andReturn().getResponse().getContentAsString();
        var ultimo = leer(cuerpo).get("ingresosUltimos6Meses").get(5);
        assertThat(ultimo.get("mes").asText()).isEqualTo(mes.toString());
        assertThat(ultimo.get("etiqueta").asText())
                .isEqualTo(mes.getMonth().getDisplayName(TextStyle.SHORT, Locale.of("es", "ES")).replace(".", ""));
    }

    @Test
    void estadisticas_mesesEnEspanolYVariacionAnual() throws Exception {
        mvc.perform(get("/api/estadisticas").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ingresos12Meses.length()").value(12))
                .andExpect(jsonPath("$.incidencias6Meses.length()").value(6))
                .andExpect(jsonPath("$.ocupacion.mantenimiento").value(1))
                .andExpect(jsonPath("$.anioActual").value(hoy.getYear()))
                .andExpect(jsonPath("$.fechaComparada").value(hoy.minusYears(1).toString()));
    }

    @Test
    void estadisticas_comparanConElAnioPasadoHastaLaMismaFecha() throws Exception {
        LocalDate haceUnAnio = hoy.minusYears(1);
        datos.pago(pagado, "300.00", haceUnAnio.withDayOfYear(1));
        // Después de la misma fecha del año pasado: cuenta en el total, no en la comparación.
        if (haceUnAnio.getDayOfYear() < haceUnAnio.lengthOfYear()) {
            datos.pago(pagado, "9000.00", haceUnAnio.withDayOfYear(haceUnAnio.lengthOfYear()));
        }
        boolean hayPagoPosterior = haceUnAnio.getDayOfYear() < haceUnAnio.lengthOfYear();
        // Los pagos del preparar() son de este mes y del anterior: solo cuentan si caen el año pasado (enero).
        mvc.perform(get("/api/estadisticas").header("Authorization", token("ana@test.com")))
                .andExpect(jsonPath("$.ingresosAnioAnteriorHastaHoy").value(hoy.getMonthValue() == 1 ? 1300.0 : 300.0))
                .andExpect(jsonPath("$.ingresosAnioAnterior").value(
                        (hoy.getMonthValue() == 1 ? 1300.0 : 300.0) + (hayPagoPosterior ? 9000.0 : 0.0)));
    }

    @Test
    void calendario_estadosDelDiaComoEnElEscritorio() throws Exception {
        String cuerpo = mvc.perform(get("/api/calendario").param("mes", mes.toString()).header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.dias.length()").value(mes.lengthOfMonth()))
                .andExpect(jsonPath("$.esperado").value(1000.00))
                .andExpect(jsonPath("$.cobrado").value(400.00))
                .andExpect(jsonPath("$.pendiente").value(600.00))
                .andReturn().getResponse().getContentAsString();
        var dias = leer(cuerpo).get("dias");
        assertThat(dias.get(0).get("estado").asText()).isEqualTo("PAGADO");
        assertThat(dias.get(0).get("pagos").size()).isEqualTo(1);
        // Hay un contrato sin pagar: los días 2 a 5 son "esperado" o "vencido" según si ya pasaron.
        String dia3 = dias.get(2).get("estado").asText();
        assertThat(dia3).isEqualTo(hoy.getDayOfMonth() >= 3 ? "VENCIDO" : "ESPERADO");
        int diaFin = pagado.getFechaFin().getDayOfMonth();
        if (YearMonth.from(pagado.getFechaFin()).equals(mes)) {
            assertThat(dias.get(diaFin - 1).get("vencimientos").size()).isEqualTo(1);
        }
    }

    @Test
    void informeMensual_esUnPdf() throws Exception {
        byte[] pdf = mvc.perform(get("/api/informes/mensual").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(new String(pdf, 0, 5)).isEqualTo("%PDF-");
    }

    @Test
    void notificaciones_generaLosCuatroTiposSinDuplicar() throws Exception {
        String t = token("ana@test.com");
        String cuerpo = mvc.perform(get("/api/notificaciones").header("Authorization", t))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        var lista = leer(cuerpo);
        var tipos = new java.util.HashSet<String>();
        lista.forEach(n -> tipos.add(n.get("tipo").asText()));
        assertThat(tipos).containsExactlyInAnyOrder("contrato_vence", "pago_pendiente", "incidencia_antigua", "mantenimiento_largo");
        assertThat(lista.size()).isEqualTo(4);
        // Con zona horaria: sin ella el móvil la leía como hora de Madrid ("dentro de 9 horas").
        lista.forEach(n -> assertThat(n.get("fecha").asText()).matches(".*(Z|[+-]\\d{2}:\\d{2})$"));
        lista.forEach(n -> assertThat(n.get("destino").get("id").isInt()).isTrue());

        // Volver a consultar no repite avisos que siguen sin leer.
        mvc.perform(get("/api/notificaciones/no-leidas").header("Authorization", t))
                .andExpect(jsonPath("$.total").value(4));

        int id = lista.get(0).get("id").asInt();
        mvc.perform(post("/api/notificaciones/" + id + "/leida").header("Authorization", t))
                .andExpect(jsonPath("$.leida").value(true));
        mvc.perform(post("/api/notificaciones/leidas").header("Authorization", t))
                .andExpect(jsonPath("$.marcadas").value(3));
        mvc.perform(get("/api/notificaciones").param("soloNoLeidas", "true").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(0));

        // La de otro usuario no se puede marcar.
        mvc.perform(post("/api/notificaciones/" + id + "/leida").header("Authorization", token("bea@test.com")))
                .andExpect(status().isNotFound());
    }

    @Test
    void notificaciones_destinoDeCadaTipo() throws Exception {
        String cuerpo = mvc.perform(get("/api/notificaciones").header("Authorization", token("ana@test.com")))
                .andReturn().getResponse().getContentAsString();
        for (var n : leer(cuerpo)) {
            String pantalla = n.get("destino").get("pantalla").asText();
            int id = n.get("destino").get("id").asInt();
            switch (n.get("tipo").asText()) {
                case "contrato_vence" -> assertThat(pantalla + id).isEqualTo("CONTRATO" + pagado.getId());
                case "pago_pendiente" -> assertThat(pantalla + id).isEqualTo("CONTRATO" + sinPagar.getId());
                case "incidencia_antigua" -> assertThat(pantalla + id).isEqualTo("INCIDENCIA" + antigua.getId());
                case "mantenimiento_largo" -> assertThat(pantalla + id).isEqualTo("HABITACION" + enMantenimiento.getId());
                default -> throw new AssertionError(n);
            }
        }
    }

    @Test
    void tendencia_comparaHastaElMismoDiaDelMesAnterior() throws Exception {
        // Un pago del mes anterior posterior al día de hoy no cuenta en la comparación.
        LocalDate anterior = hoy.minusMonths(1);
        if (hoy.getDayOfMonth() < anterior.lengthOfMonth()) {
            datos.pago(pagado, "5000.00", anterior.withDayOfMonth(anterior.lengthOfMonth()));
        }
        // Mes anterior hasta hoy: 400 (día 1) + 600 (día 2, si hoy es al menos día 2).
        BigDecimal esperado = new BigDecimal(hoy.getDayOfMonth() >= 2 ? "1000.00" : "400.00");
        mvc.perform(get("/api/dashboard").header("Authorization", token("ana@test.com")))
                .andExpect(jsonPath("$.cobradoMesAnteriorMismoDia").value(esperado.doubleValue()))
                .andExpect(jsonPath("$.tendenciaPct").value(
                        new BigDecimal("400").subtract(esperado).divide(esperado, 4, java.math.RoundingMode.HALF_UP)
                                .multiply(BigDecimal.valueOf(100)).doubleValue()))
                .andExpect(jsonPath("$.mesComparado").value(
                        anterior.getMonth().getDisplayName(TextStyle.SHORT, Locale.of("es", "ES")).replace(".", "")));
    }

    @Test
    void actividad_propietarioVeLaSuya_sinInicioDeSesion() throws Exception {
        String t = token("ana@test.com"); // el login registra LOGIN_API
        token("bea@test.com");
        actividadService.registrar(ana.getId(), "REGISTRAR_PAGO", "Pago de 400 €");
        mvc.perform(get("/api/actividad").header("Authorization", t))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].accion").value("REGISTRAR_PAGO"));
        mvc.perform(get("/api/dashboard").header("Authorization", t))
                .andExpect(jsonPath("$.actividadReciente.length()").value(1));
        // En el historial del perfil sí salen los accesos.
        mvc.perform(get("/api/actividad").param("soloMia", "true").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(2));
    }

    @Test
    void inquilino_403EnLosPaneles() throws Exception {
        datos.usuario("inq@test.com", Rol.INQUILINO);
        String t = token("inq@test.com");
        mvc.perform(get("/api/dashboard").header("Authorization", t)).andExpect(status().isForbidden());
        mvc.perform(get("/api/notificaciones").header("Authorization", t))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }
}
