package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.repository.GastoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Estadísticas de un periodo: cálculo, ámbitos, autorización y validación. */
class AnalisisIntegrationTest extends IntegrationTest {

    @Autowired GastoRepository gastos;

    Piso pisoA;
    Piso pisoB;
    Piso deBea;
    Habitacion h1;
    Habitacion h2;
    Habitacion h3;
    Inquilino lucia;

    @BeforeEach
    void preparar() {
        Ciudad madrid = datos.ciudad("Madrid");
        Usuario ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Usuario bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        datos.usuario("inq@test.com", Rol.INQUILINO);
        pisoA = datos.piso("Calle A 1", madrid, ana);
        pisoB = datos.piso("Calle B 2", madrid, ana);
        deBea = datos.piso("Calle de Bea 3", madrid, bea);
        h1 = datos.habitacion(pisoA, 1, EstadoHabitacion.disponible);
        h2 = datos.habitacion(pisoA, 2, EstadoHabitacion.disponible);
        h3 = datos.habitacion(pisoB, 1, EstadoHabitacion.disponible);
        datos.habitacion(deBea, 1, EstadoHabitacion.disponible);

        lucia = datos.inquilinoDe(ana, "11111111A");
        Inquilino pedro = datos.inquilinoDe(ana, "22222222B");
        Contrato c1 = datos.contrato(h1, lucia, "500.00", LocalDate.of(2025, 1, 1), LocalDate.of(2025, 12, 31));
        Contrato c2 = datos.contrato(h2, pedro, "400.00", LocalDate.of(2025, 7, 1), LocalDate.of(2025, 12, 31));
        for (int m = 1; m <= 12; m++) {
            if (m == 3) continue; // marzo sin pagar
            datos.pago(c1, "500.00", LocalDate.of(2025, m, m == 6 ? 10 : 3)); // junio, fuera de plazo
        }
        for (int m = 7; m <= 12; m++) datos.pago(c2, "400.00", LocalDate.of(2025, m, 1));
        gasto(pisoA, null, "100.00", LocalDate.of(2025, 2, 1));
        gasto(pisoB, null, "50.00", LocalDate.of(2025, 5, 1));
        gasto(pisoA, h2, "30.00", LocalDate.of(2025, 8, 1));
    }

    private void gasto(Piso p, Habitacion h, String importe, LocalDate fecha) {
        Gasto g = new Gasto();
        g.setPiso(p);
        g.setHabitacion(h);
        g.setCategoria(Gasto.Categoria.REPARACION);
        g.setConcepto("Arreglo");
        g.setImporte(new BigDecimal(importe));
        g.setFecha(fecha);
        gastos.save(g);
    }

    private org.springframework.test.web.servlet.ResultActions pedir(String email, String... params) throws Exception {
        var req = get("/api/estadisticas/analisis").header("Authorization", token(email));
        for (int i = 0; i < params.length; i += 2) req = req.param(params[i], params[i + 1]);
        return mvc.perform(req);
    }

    @Test
    void cartera_ingresosGastosOcupacionMorosidadRotacionYRanking() throws Exception {
        pedir("ana@test.com", "desde", "2025-01-01", "hasta", "2025-12-31")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ambito").value("CARTERA"))
                .andExpect(jsonPath("$.actual.ingresos").value(7900.00))
                .andExpect(jsonPath("$.actual.gastos").value(180.00))
                .andExpect(jsonPath("$.actual.neto").value(7720.00))
                .andExpect(jsonPath("$.actual.habitaciones").value(3))
                // 365 + 184 días alquilados de 3 × 365.
                .andExpect(jsonPath("$.actual.ocupacionPct").value(50.14))
                .andExpect(jsonPath("$.actual.diasMediosVacia").value(182.0))
                .andExpect(jsonPath("$.actual.contratosIniciados").value(2))
                .andExpect(jsonPath("$.actual.contratosFinalizados").value(2))
                .andExpect(jsonPath("$.actual.rotacionPct").value(66.67))
                .andExpect(jsonPath("$.actual.impagado").value(500.00))
                .andExpect(jsonPath("$.anterior.ingresos").value(0))
                .andExpect(jsonPath("$.meses.length()").value(12))
                .andExpect(jsonPath("$.meses[2].ingresos").value(0))
                .andExpect(jsonPath("$.meses[11].ocupacionPct").value(66.67))
                .andExpect(jsonPath("$.pisos.length()").value(2))
                .andExpect(jsonPath("$.pisos[0].piso.direccion").value("Calle A 1"))
                .andExpect(jsonPath("$.pisos[0].neto").value(7770.00))
                .andExpect(jsonPath("$.pisos[1].neto").value(-50.00))
                .andExpect(jsonPath("$.morosidad[0].idInquilino").value(lucia.getId()))
                .andExpect(jsonPath("$.morosidad[0].mesesDebidos").value(12))
                .andExpect(jsonPath("$.morosidad[0].mesesImpagados").value(1))
                .andExpect(jsonPath("$.morosidad[0].pagosFueraDePlazo").value(1))
                .andExpect(jsonPath("$.morosidad[0].importeImpagado").value(500.00))
                .andExpect(jsonPath("$.morosidad[0].puntualidadPct").value(83.33))
                .andExpect(jsonPath("$.morosidad[1].puntualidadPct").value(100.0));
    }

    @Test
    void pisoYHabitacion_soloSuParte_yElAnioAnteriorComparable() throws Exception {
        pedir("ana@test.com", "desde", "2025-01-01", "hasta", "2025-12-31", "piso", pisoB.getId().toString())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ambito").value("PISO"))
                .andExpect(jsonPath("$.actual.ingresos").value(0))
                .andExpect(jsonPath("$.actual.gastos").value(50.00))
                .andExpect(jsonPath("$.actual.ocupacionPct").value(0.0));
        pedir("ana@test.com", "desde", "2025-01-01", "hasta", "2025-12-31", "habitacion", h2.getId().toString())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ambito").value("HABITACION"))
                .andExpect(jsonPath("$.actual.ingresos").value(2400.00))
                .andExpect(jsonPath("$.actual.gastos").value(30.00))
                .andExpect(jsonPath("$.morosidad.length()").value(1));
        pedir("ana@test.com", "desde", "2026-01-01", "hasta", "2026-03-31")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.anterior.ingresos").value(1000.00)); // enero y febrero de 2025
        // Meses que aún no han empezado: sin ocupación (no es un 0 %).
        int anio = LocalDate.now().getYear() + 1;
        pedir("ana@test.com", "desde", anio + "-01-01", "hasta", anio + "-02-28")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.meses[0].ocupacionPct").doesNotExist());
    }

    @Test
    void autorizacionYValidacion() throws Exception {
        pedir("bea@test.com", "desde", "2025-01-01", "hasta", "2025-12-31", "piso", pisoA.getId().toString())
                .andExpect(status().isNotFound());
        pedir("bea@test.com", "desde", "2025-01-01", "hasta", "2025-12-31", "habitacion", h1.getId().toString())
                .andExpect(status().isNotFound());
        pedir("bea@test.com", "desde", "2025-01-01", "hasta", "2025-12-31")
                .andExpect(status().isOk()).andExpect(jsonPath("$.actual.ingresos").value(0));
        pedir("ana@test.com", "desde", "2025-01-01", "hasta", "2025-12-31",
                "piso", pisoA.getId().toString(), "habitacion", h3.getId().toString())
                .andExpect(status().isBadRequest());
        pedir("ana@test.com", "desde", "2025-12-31", "hasta", "2025-01-01").andExpect(status().isBadRequest());
        pedir("ana@test.com", "desde", "2018-01-01", "hasta", "2025-01-01").andExpect(status().isBadRequest());
        pedir("ana@test.com", "desde", "no-es-fecha", "hasta", "2025-01-01").andExpect(status().isBadRequest());
        pedir("ana@test.com", "hasta", "2025-01-01").andExpect(status().isBadRequest());
        pedir("inq@test.com", "desde", "2025-01-01", "hasta", "2025-12-31").andExpect(status().isForbidden());
        mvc.perform(get("/api/estadisticas/analisis").param("desde", "2025-01-01").param("hasta", "2025-12-31"))
                .andExpect(status().isUnauthorized());
    }
}
