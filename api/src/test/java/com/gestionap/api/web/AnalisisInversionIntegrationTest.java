package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.repository.AnalisisInversionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Análisis de inversión guardados: CRUD propio, IDOR, validación, límite y roles. */
class AnalisisInversionIntegrationTest extends IntegrationTest {

    @Autowired AnalisisInversionRepository repo;
    Piso pisoAna;
    Piso pisoBea;
    Usuario ana;

    @BeforeEach
    void preparar() {
        Ciudad madrid = datos.ciudad("Madrid");
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Usuario bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        datos.usuario("admin@test.com", Rol.ADMIN);
        datos.usuario("inq@test.com", Rol.INQUILINO);
        pisoAna = datos.piso("Calle de Ana 1", madrid, ana);
        pisoBea = datos.piso("Calle de Bea 2", madrid, bea);
    }

    private Map<String, Object> entrada(double precio, double alquiler) {
        Map<String, Object> e = new HashMap<>();
        e.put("comunidad", "Madrid");
        e.put("precioCompra", precio);
        e.put("alquilerMensual", alquiler);
        e.put("porcentajeFinanciado", 80);
        e.put("plazoAnos", 25);
        e.put("tipoInteresPct", 3);
        return e;
    }

    private Map<String, Object> peticion(String nombre, Integer idPiso, Map<String, Object> entrada) {
        Map<String, Object> m = new HashMap<>();
        m.put("nombre", nombre);
        m.put("idPiso", idPiso);
        m.put("entrada", entrada);
        return m;
    }

    private org.springframework.test.web.servlet.ResultActions crear(String email, Object cuerpo) throws Exception {
        return mvc.perform(post("/api/analisis-inversion").header("Authorization", token(email))
                .contentType(MediaType.APPLICATION_JSON).content(json(cuerpo)));
    }

    @Test
    void crearListarCambiarYBorrar_conResultadoRecalculado() throws Exception {
        String cuerpo = crear("ana@test.com", peticion("  Piso de Ana  ", pisoAna.getId(), entrada(200000, 1400)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.nombre").value("Piso de Ana"))
                .andExpect(jsonPath("$.idPiso").value(pisoAna.getId()))
                .andExpect(jsonPath("$.entrada.precioCompra").value(200000.0))
                .andExpect(jsonPath("$.resultado.rentabilidadBrutaPct").isNumber())
                .andReturn().getResponse().getContentAsString();
        int id = leer(cuerpo).get("id").asInt();
        crear("ana@test.com", peticion("Piso nuevo", null, entrada(150000, 900))).andExpect(status().isCreated());

        mvc.perform(get("/api/analisis-inversion").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].nombre").value("Piso nuevo"));

        mvc.perform(put("/api/analisis-inversion/" + id).header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(peticion("Piso de Ana con reforma", pisoAna.getId(), entrada(200000, 1600)))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nombre").value("Piso de Ana con reforma"))
                .andExpect(jsonPath("$.entrada.alquilerMensual").value(1600.0));

        mvc.perform(delete("/api/analisis-inversion/" + id).header("Authorization", token("ana@test.com")))
                .andExpect(status().isNoContent());
        mvc.perform(get("/api/analisis-inversion").header("Authorization", token("ana@test.com")))
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void cadaUnoSoloLosSuyos_tambienElAdmin() throws Exception {
        String cuerpo = crear("ana@test.com", peticion("De Ana", null, entrada(200000, 1400)))
                .andReturn().getResponse().getContentAsString();
        int id = leer(cuerpo).get("id").asInt();
        for (String otro : new String[]{"bea@test.com", "admin@test.com"}) {
            mvc.perform(get("/api/analisis-inversion").header("Authorization", token(otro)))
                    .andExpect(status().isOk()).andExpect(jsonPath("$.length()").value(0));
            mvc.perform(put("/api/analisis-inversion/" + id).header("Authorization", token(otro))
                            .contentType(MediaType.APPLICATION_JSON).content(json(peticion("Mío", null, entrada(1, 1)))))
                    .andExpect(status().isNotFound());
            mvc.perform(delete("/api/analisis-inversion/" + id).header("Authorization", token(otro)))
                    .andExpect(status().isNotFound());
        }
        // Un piso ajeno no se puede asociar.
        crear("bea@test.com", peticion("Con piso de Ana", pisoAna.getId(), entrada(200000, 1400)))
                .andExpect(status().isNotFound());
    }

    @Test
    void validacion_limiteYRoles() throws Exception {
        crear("ana@test.com", peticion("", null, entrada(200000, 1400))).andExpect(status().isBadRequest());
        crear("ana@test.com", peticion("x".repeat(81), null, entrada(200000, 1400))).andExpect(status().isBadRequest());
        crear("ana@test.com", peticion("Sin datos", null, null)).andExpect(status().isBadRequest());
        crear("ana@test.com", peticion("Negativo", null, entrada(-1, 1400))).andExpect(status().isBadRequest());
        crear("ana@test.com", peticion("Enorme", null, entrada(1e12, 1400))).andExpect(status().isBadRequest());
        var rara = entrada(200000, 1400);
        rara.put("comunidad", "Atlántida");
        crear("ana@test.com", peticion("Comunidad", null, rara)).andExpect(status().isBadRequest());
        // Campos que no son de la petición (p. ej. el dueño) se ignoran.
        var colado = peticion("Colado", null, entrada(200000, 1400));
        colado.put("idUsuario", 999);
        crear("ana@test.com", colado).andExpect(status().isCreated());
        org.assertj.core.api.Assertions.assertThat(repo.findAll()).allMatch(a -> a.getIdUsuario().equals(ana.getId()));

        for (int i = repo.findAll().size(); i < 50; i++) {
            AnalisisInversion a = new AnalisisInversion();
            a.setIdUsuario(ana.getId());
            a.setNombre("Relleno " + i);
            a.setDatos(json(entrada(1000, 10)));
            a.setFechaCreacion(LocalDateTime.now());
            a.setFechaActualizacion(LocalDateTime.now());
            repo.save(a);
        }
        crear("ana@test.com", peticion("El 51", null, entrada(200000, 1400))).andExpect(status().isConflict());

        crear("inq@test.com", peticion("Inquilino", null, entrada(200000, 1400))).andExpect(status().isForbidden());
        mvc.perform(get("/api/analisis-inversion")).andExpect(status().isUnauthorized());
    }
}
