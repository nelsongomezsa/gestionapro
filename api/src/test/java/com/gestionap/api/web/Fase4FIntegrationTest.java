package com.gestionap.api.web;

import com.gestionap.api.Datos;
import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.LocalDate;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Perfil (contraseña, actividad propia), usuarios (solo admin) y búsqueda global. */
class Fase4FIntegrationTest extends IntegrationTest {

    Usuario admin;
    Usuario ana;
    Usuario inquilinoCuenta;

    @BeforeEach
    void preparar() {
        Ciudad madrid = datos.ciudad("Madrid");
        admin = datos.usuario("admin@test.com", Rol.ADMIN);
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Usuario bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        inquilinoCuenta = datos.usuario("lucia@test.com", Rol.INQUILINO);
        Piso pisoAna = datos.piso("Calle Mayor 15", madrid, ana);
        Piso pisoBea = datos.piso("Calle Mayor 99", madrid, bea);
        Habitacion h = datos.habitacion(pisoAna, 1, EstadoHabitacion.alquilada);
        Inquilino lucia = datos.inquilinoDe(ana, "11111111A");
        lucia.setNombre("Lucía");
        datos.contrato(h, lucia, "450.00", LocalDate.now().minusMonths(1), LocalDate.now().plusMonths(11));
        datos.incidencia(h, lucia, "Persiana rota en Calle Mayor");
        datos.habitacion(pisoBea, 1, EstadoHabitacion.disponible);
    }

    // ── Contraseña ──

    @Test
    void cambiarPassword_compruebaLaActual() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(put("/api/me/password").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("actual", "mala", "nueva", "nueva-clave-1"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("PASSWORD_ACTUAL_INCORRECTA"));
        mvc.perform(put("/api/me/password").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("actual", Datos.PASSWORD, "nueva", "corta"))))
                .andExpect(status().isBadRequest());
        mvc.perform(put("/api/me/password").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("actual", Datos.PASSWORD, "nueva", Datos.PASSWORD))))
                .andExpect(jsonPath("$.codigo").value("PASSWORD_IGUAL"));
        mvc.perform(put("/api/me/password").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("actual", Datos.PASSWORD, "nueva", "nueva-clave-1"))))
                .andExpect(status().isNoContent());
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "ana@test.com", "password", "nueva-clave-1"))))
                .andExpect(status().isOk());
    }

    @Test
    void editarNombreYEmail() throws Exception {
        mvc.perform(patch("/api/me").header("Authorization", token("ana@test.com")).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombre\":\"Ana Pérez\",\"email\":\"ANA.PEREZ@test.com\"}"))
                .andExpect(jsonPath("$.nombre").value("Ana Pérez"))
                .andExpect(jsonPath("$.email").value("ana.perez@test.com"));
    }

    @Test
    void actividadPropia_inclusoParaElAdmin() throws Exception {
        token("ana@test.com");
        String t = token("admin@test.com");
        mvc.perform(get("/api/actividad").header("Authorization", t)).andExpect(jsonPath("$.length()").value(2));
        mvc.perform(get("/api/actividad").param("soloMia", "true").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(1));
    }

    // ── Usuarios ──

    @Test
    void usuarios_soloAdmin() throws Exception {
        mvc.perform(get("/api/usuarios").header("Authorization", token("ana@test.com"))).andExpect(status().isForbidden());
        mvc.perform(get("/api/usuarios").header("Authorization", token("admin@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(4));
    }

    @Test
    void crearUsuario_noInquilinos_niEmailRepetido() throws Exception {
        String t = token("admin@test.com");
        mvc.perform(post("/api/usuarios").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("nombre", "Carla", "email", "carla@test.com", "password", "clave-segura", "rol", "PROPIETARIO"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.activo").value(true));
        mvc.perform(post("/api/usuarios").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("nombre", "X", "email", "x@test.com", "password", "clave-segura", "rol", "INQUILINO"))))
                .andExpect(jsonPath("$.codigo").value("ROL_NO_PERMITIDO"));
        mvc.perform(post("/api/usuarios").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("nombre", "Y", "email", "ANA@test.com", "password", "clave-segura", "rol", "ADMIN"))))
                .andExpect(status().isConflict());
    }

    @Test
    void activarDesactivar_peroNoAUnoMismo() throws Exception {
        String t = token("admin@test.com");
        mvc.perform(patch("/api/usuarios/" + ana.getId() + "/activo").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"activo\":false}"))
                .andExpect(jsonPath("$.activo").value(false));
        mvc.perform(patch("/api/usuarios/" + admin.getId() + "/activo").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"activo\":false}"))
                .andExpect(jsonPath("$.codigo").value("NO_PUEDES_DESACTIVARTE"));
    }

    @Test
    void cambiarRol_comoElParcheDelEscritorio() throws Exception {
        String t = token("admin@test.com");
        mvc.perform(patch("/api/usuarios/" + ana.getId() + "/rol").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"rol\":\"ADMIN\"}"))
                .andExpect(jsonPath("$.rol").value("ADMIN"));
        mvc.perform(patch("/api/usuarios/" + inquilinoCuenta.getId() + "/rol").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"rol\":\"PROPIETARIO\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("INQUILINO_NO_CAMBIA_ROL"));
        mvc.perform(patch("/api/usuarios/" + admin.getId() + "/rol").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"rol\":\"PROPIETARIO\"}"))
                .andExpect(jsonPath("$.codigo").value("NO_PUEDES_CAMBIAR_TU_ROL"));
    }

    // ── Búsqueda global ──

    @Test
    void busqueda_sinTildesYSoloLoPropio() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(get("/api/buscar").param("q", "mayor").header("Authorization", t))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.pisos.length()").value(1))
                .andExpect(jsonPath("$.pisos[0].titulo").value("Calle Mayor 15"))
                .andExpect(jsonPath("$.contratos.length()").value(1))
                .andExpect(jsonPath("$.incidencias.length()").value(1));
        mvc.perform(get("/api/buscar").param("q", "lucia").header("Authorization", t))
                .andExpect(jsonPath("$.inquilinos.length()").value(1))
                .andExpect(jsonPath("$.inquilinos[0].subtitulo").value("Hab. 1 · Calle Mayor 15"));
        mvc.perform(get("/api/buscar").param("q", "m").header("Authorization", t))
                .andExpect(jsonPath("$.codigo").value("BUSQUEDA_CORTA"));
    }
}
