package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.repository.NotificacionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Cada aviso una sola vez: ni al consultar varias veces ni con copias creadas por el escritorio. */
class NotificacionesDuplicadasTest extends IntegrationTest {

    @Autowired NotificacionRepository notificaciones;

    final LocalDate hoy = LocalDate.now();
    Usuario ana;
    Incidencia antigua;

    @BeforeEach
    void preparar() {
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Habitacion h = datos.habitacion(datos.piso("Calle de Ana 1", datos.ciudad("Madrid"), ana), 1, EstadoHabitacion.alquilada);
        Inquilino lucia = datos.inquilinoDe(ana, "11111111A");
        datos.contrato(h, lucia, "450.00", hoy.minusMonths(3), hoy.plusMonths(9));
        antigua = datos.incidencia(h, lucia, "Gotera");
        antigua.setFecha(hoy.minusDays(20));
    }

    @Test
    void consultarVariasVeces_noCreaCopias() throws Exception {
        String t = token("ana@test.com");
        for (int i = 0; i < 3; i++) {
            mvc.perform(get("/api/notificaciones").header("Authorization", t)).andExpect(status().isOk());
            mvc.perform(get("/api/notificaciones/no-leidas").header("Authorization", t)).andExpect(status().isOk());
        }
        var todas = notificaciones.findAll().stream().filter(n -> n.getIdUsuario().equals(ana.getId())).toList();
        assertThat(todas).extracting(Notificacion::getReferencia).doesNotHaveDuplicates();
        // Leído un aviso, no vuelve a crearse al día siguiente (una vez por tipo + incidencia).
        notificaciones.findAll().forEach(n -> n.setLeida(true));
        mvc.perform(get("/api/notificaciones/no-leidas").header("Authorization", t)).andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void copiasDelEscritorio_seMuestranUnaVez_ySeMarcanTodas() throws Exception {
        String t = token("ana@test.com");
        for (int i = 0; i < 4; i++) {
            Notificacion n = new Notificacion();
            n.setIdUsuario(ana.getId());
            n.setReferencia("incidencia_antigua_" + antigua.getId());
            n.setTipo("incidencia_antigua");
            n.setTitulo("Incidencia sin resolver > 7 días");
            n.setFecha(LocalDateTime.now().minusDays(i + 1));
            notificaciones.save(n);
        }
        String cuerpo = mvc.perform(get("/api/notificaciones").header("Authorization", t))
                .andReturn().getResponse().getContentAsString();
        var lista = leer(cuerpo);
        long deLaIncidencia = 0;
        int id = 0;
        for (var n : lista) {
            if (n.get("tipo").asText().equals("incidencia_antigua")) {
                deLaIncidencia++;
                id = n.get("id").asInt();
            }
        }
        assertThat(deLaIncidencia).isEqualTo(1);
        long total = lista.size();
        mvc.perform(get("/api/notificaciones/no-leidas").header("Authorization", t)).andExpect(jsonPath("$.total").value(total));
        mvc.perform(post("/api/notificaciones/" + id + "/leida").header("Authorization", t));
        assertThat(notificaciones.findAll().stream()
                .filter(n -> ("incidencia_antigua_" + antigua.getId()).equals(n.getReferencia()))
                .allMatch(Notificacion::isLeida)).isTrue();
        mvc.perform(get("/api/notificaciones/no-leidas").header("Authorization", t)).andExpect(jsonPath("$.total").value(total - 1));
    }
}
