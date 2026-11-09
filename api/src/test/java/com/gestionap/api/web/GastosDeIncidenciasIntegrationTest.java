package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.repository.GastoRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * El coste de reparación de una incidencia pasa a Gastos al marcarla como resuelta (o al ponerle coste
 * ya resuelta), una sola vez. Los informes (gastos, resumen fiscal, informe mensual) son solo lectura.
 */
class GastosDeIncidenciasIntegrationTest extends IntegrationTest {

    @Autowired GastoRepository gastos;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager em;

    Piso piso;
    Incidencia incidencia;
    String token;
    final int anio = LocalDate.now().getYear();

    @BeforeEach
    void preparar() throws Exception {
        Usuario ana = datos.usuario("ana-incidencias@test.com", Rol.PROPIETARIO);
        piso = datos.piso("Calle Reparaciones 3", datos.ciudad("Madrid"), ana);
        Habitacion h = datos.habitacion(piso, 1, EstadoHabitacion.alquilada);
        Inquilino lucia = datos.inquilinoDe(ana, "33333333P");
        datos.contrato(h, lucia, "500.00", LocalDate.of(anio, 1, 1), LocalDate.of(anio + 1, 12, 31));
        incidencia = datos.incidencia(h, lucia, "Caldera averiada");
        token = token("ana-incidencias@test.com");
    }

    private void enviar(String ruta, String cuerpo) throws Exception {
        mvc.perform(patch(ruta)
                        .header("Authorization", token).contentType(MediaType.APPLICATION_JSON).content(cuerpo))
                .andExpect(status().isOk());
    }

    private long gastosDeLaIncidencia() {
        em.flush();
        return jdbc.queryForObject("select count(*) from Gastos where id_incidencia = ?", Long.class, incidencia.getId());
    }

    /** Huella de todas las tablas que un informe podría tocar: filas y contenido. */
    private Map<String, List<Map<String, Object>>> estado() {
        em.flush();
        Map<String, List<Map<String, Object>>> e = new LinkedHashMap<>();
        for (String t : List.of("Gastos", "Incidencias", "Recibos", "Pagos", "Contratos", "actividad")) {
            e.put(t, jdbc.queryForList("select * from " + t + " order by 1"));
        }
        return e;
    }

    @Test
    void alResolverlaConCoste_seApuntaUnaVez_yNoSeDuplica() throws Exception {
        enviar("/api/incidencias/" + incidencia.getId(), "{\"costeReparacion\":320.50}");
        assertThat(gastosDeLaIncidencia()).as("sin resolver no es gasto").isZero();

        enviar("/api/incidencias/" + incidencia.getId() + "/estado", "{\"estado\":\"resuelta\"}");
        assertThat(gastosDeLaIncidencia()).isEqualTo(1);
        Gasto g = gastos.findByIdIncidencia(incidencia.getId()).orElseThrow();
        assertThat(g.getImporte()).isEqualByComparingTo("320.50");
        assertThat(g.getCategoria()).isEqualTo(Gasto.Categoria.REPARACION);
        assertThat(g.getFecha()).isEqualTo(incidencia.getFecha());

        // Volver a resolverla o cambiarle el coste no crea otro gasto: actualiza el mismo.
        enviar("/api/incidencias/" + incidencia.getId() + "/estado", "{\"estado\":\"resuelta\"}");
        enviar("/api/incidencias/" + incidencia.getId(), "{\"costeReparacion\":300.00}");
        assertThat(gastosDeLaIncidencia()).isEqualTo(1);
        assertThat(gastos.findByIdIncidencia(incidencia.getId()).orElseThrow().getImporte()).isEqualByComparingTo("300.00");
    }

    @Test
    void resueltaSinCoste_noEsGasto_hastaQueSeLePone() throws Exception {
        enviar("/api/incidencias/" + incidencia.getId() + "/estado", "{\"estado\":\"resuelta\"}");
        assertThat(gastosDeLaIncidencia()).isZero();
        enviar("/api/incidencias/" + incidencia.getId(), "{\"costeReparacion\":80.00}");
        assertThat(gastosDeLaIncidencia()).isEqualTo(1);
    }

    @Test
    void gastoYaExistente_alResolver_noSeDuplica() throws Exception {
        // Un gasto ya apuntado (p. ej., por la versión anterior de la API) para esta incidencia.
        Gasto previo = new Gasto();
        previo.setPiso(piso);
        previo.setIdIncidencia(incidencia.getId());
        previo.setCategoria(Gasto.Categoria.REPARACION);
        previo.setConcepto("Incidencia: Caldera averiada");
        previo.setImporte(new BigDecimal("150.00"));
        previo.setFecha(incidencia.getFecha());
        previo.setDeducible(true);
        gastos.save(previo);
        enviar("/api/incidencias/" + incidencia.getId(), "{\"costeReparacion\":150.00}");
        enviar("/api/incidencias/" + incidencia.getId() + "/estado", "{\"estado\":\"resuelta\"}");
        assertThat(gastosDeLaIncidencia()).isEqualTo(1);
        assertThat(gastos.findByIdIncidencia(incidencia.getId()).orElseThrow().getId()).isEqualTo(previo.getId());
    }

    /** Incidencia resuelta con coste y sin gasto (como las que se resolvían fuera de la API): los informes no la apuntan. */
    @Test
    void informes_soloLectura_noModificanNada() throws Exception {
        incidencia.setEstado(EstadoIncidencia.resuelta);
        incidencia.setCosteReparacion(new BigDecimal("210.00"));
        var antes = estado();
        String mes = LocalDate.now().toString().substring(0, 7);
        for (String ruta : List.of("/api/gastos", "/api/gastos?piso=" + piso.getId() + "&anio=" + anio,
                "/api/pisos/" + piso.getId() + "/resumen-fiscal?anio=" + anio,
                "/api/pisos/" + piso.getId() + "/resumen-fiscal/pdf?anio=" + anio,
                "/api/pisos/" + piso.getId() + "/resumen-fiscal/csv?anio=" + anio,
                "/api/informes/mensual?mes=" + mes, "/api/informes/mensual",
                "/api/estadisticas/analisis?desde=" + anio + "-01-01&hasta=" + anio + "-12-31",
                "/api/dashboard", "/api/pisos/" + piso.getId() + "/pdf")) {
            mvc.perform(get(ruta).header("Authorization", token)).andExpect(status().isOk());
        }
        assertThat(estado()).isEqualTo(antes);
        assertThat(gastosDeLaIncidencia()).isZero();
    }
}
