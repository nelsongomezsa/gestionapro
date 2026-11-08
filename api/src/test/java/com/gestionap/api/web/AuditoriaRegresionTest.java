package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Base64;
import java.util.Date;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Regresión de la auditoría de seguridad (fase B, 2026-11-07): los ataques que resistió la API se
 * repiten aquí para que un cambio de versión (Spring Boot 4, Security 7) no abra ninguno.
 */
class AuditoriaRegresionTest extends IntegrationTest {

    private static final String CLAVE_TEST = "clave-de-tests-no-secreta-solo-para-mvn-test-0000";

    Usuario ana;
    Usuario bea;
    Piso pisoAna;
    Habitacion habAna;
    Inquilino luciaDeAna;
    Contrato contratoAna;
    Pago pagoAna;
    Incidencia incidenciaAna;

    @BeforeEach
    void preparar() {
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        pisoAna = datos.piso("Calle de Ana 1", datos.ciudad("Madrid"), ana);
        habAna = datos.habitacion(pisoAna, 1, EstadoHabitacion.alquilada);
        luciaDeAna = datos.inquilinoDe(ana, "11111111H");
        contratoAna = datos.contrato(habAna, luciaDeAna, "450.00", LocalDate.of(2026, 1, 1), LocalDate.of(2027, 12, 31));
        pagoAna = datos.pago(contratoAna, "450.00", LocalDate.of(2026, 2, 3));
        incidenciaAna = datos.incidencia(habAna, luciaDeAna, "Grifo");
    }

    // ---------- Aislamiento entre usuarios (IDOR) ----------

    @Test
    void otroPropietario_noLeeNiCambiaNiBorraNadaAjeno() throws Exception {
        String t = token("bea@test.com");
        List<String> lecturas = List.of("/api/pisos/" + pisoAna.getId(), "/api/habitaciones/" + habAna.getId(),
                "/api/inquilinos/" + luciaDeAna.getId(), "/api/contratos/" + contratoAna.getId(),
                "/api/contratos/" + contratoAna.getId() + "/pdf", "/api/contratos/" + contratoAna.getId() + "/fianza",
                "/api/contratos/" + contratoAna.getId() + "/mensajes", "/api/incidencias/" + incidenciaAna.getId(),
                "/api/pagos/" + pagoAna.getId() + "/recibo", "/api/inquilinos/" + luciaDeAna.getId() + "/qr-pago",
                "/api/pisos/" + pisoAna.getId() + "/ingresos", "/api/habitaciones/" + habAna.getId() + "/inventarios");
        for (String ruta : lecturas) {
            mvc.perform(get(ruta).header("Authorization", t)).andExpect(status().is(anyOf(is(403), is(404))));
        }
        mvc.perform(put("/api/pisos/" + pisoAna.getId()).header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("direccion", "Robado 1", "idCiudad", pisoAna.getCiudad().getId(), "numeroHabitaciones", 3))))
                .andExpect(status().is(anyOf(is(403), is(404))));
        mvc.perform(delete("/api/pisos/" + pisoAna.getId()).header("Authorization", t)).andExpect(status().is(anyOf(is(403), is(404))));
        mvc.perform(delete("/api/pagos/" + pagoAna.getId()).header("Authorization", t)).andExpect(status().is(anyOf(is(403), is(404))));
        mvc.perform(delete("/api/incidencias/" + incidenciaAna.getId()).header("Authorization", t)).andExpect(status().is(anyOf(is(403), is(404))));
        mvc.perform(post("/api/contratos/" + contratoAna.getId() + "/finalizar").header("Authorization", t))
                .andExpect(status().is(anyOf(is(403), is(404))));
        // Sus listados no incluyen nada de Ana.
        for (String ruta : List.of("/api/pisos", "/api/habitaciones", "/api/inquilinos", "/api/contratos", "/api/incidencias",
                "/api/pagos?mes=2026-02", "/api/fianzas")) {
            String cuerpo = mvc.perform(get(ruta).header("Authorization", t)).andExpect(status().isOk())
                    .andReturn().getResponse().getContentAsString();
            assertThat(cuerpo).as(ruta).doesNotContain("Calle de Ana").doesNotContain("11111111H");
        }
    }

    @Test
    void inquilino_soloLoSuyo_ynadaDeGestion() throws Exception {
        luciaDeAna.setUsuario(datos.usuario("lucia@test.com", Rol.INQUILINO));
        String t = token("lucia@test.com");
        for (String ruta : List.of("/api/pisos", "/api/habitaciones", "/api/inquilinos", "/api/gastos", "/api/usuarios",
                "/api/dashboard", "/api/analisis-inversion", "/api/buscar?q=Ana")) {
            mvc.perform(get(ruta).header("Authorization", t)).andExpect(status().isForbidden());
        }
        mvc.perform(post("/api/usuarios").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("email", "x@test.com", "password", "Larga-y-rara-2026", "nombre", "X", "rol", "ADMIN"))))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/contratos").header("Authorization", t)).andExpect(jsonPath("$.length()").value(1));
    }

    // ---------- JWT manipulado ----------

    private static String b64(String s) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(s.getBytes(StandardCharsets.UTF_8));
    }

    @Test
    void jwtManipulado_siempre401() throws Exception {
        String bueno = token("ana@test.com").substring(7);
        String[] partes = bueno.split("\\.");
        String payload = new String(Base64.getUrlDecoder().decode(partes[1]), StandardCharsets.UTF_8);
        String sinFirma = b64("{\"alg\":\"none\",\"typ\":\"JWT\"}") + "." + partes[1];
        String comoAdmin = partes[0] + "." + b64(payload.replace("\"PROPIETARIO\"", "\"ADMIN\"")) + "." + partes[2];
        String otroUsuario = partes[0] + "." + b64(payload.replaceFirst("\"sub\":\"\\d+\"", "\"sub\":\"" + bea.getId() + "\"")) + "." + partes[2];
        String otraClave = Jwts.builder().issuer("gestionapro-api").subject(String.valueOf(ana.getId())).claim("rol", "ADMIN")
                .expiration(Date.from(Instant.now().plusSeconds(600)))
                .signWith(Keys.hmacShaKeyFor("otra-clave-distinta-de-al-menos-32-bytes!!".getBytes(StandardCharsets.UTF_8))).compact();
        String caducado = Jwts.builder().issuer("gestionapro-api").subject(String.valueOf(ana.getId()))
                .issuedAt(Date.from(Instant.now().minusSeconds(7200))).expiration(Date.from(Instant.now().minusSeconds(60)))
                .signWith(Keys.hmacShaKeyFor(CLAVE_TEST.getBytes(StandardCharsets.UTF_8))).compact();
        String otroEmisor = Jwts.builder().issuer("otro").subject(String.valueOf(ana.getId()))
                .expiration(Date.from(Instant.now().plusSeconds(600)))
                .signWith(Keys.hmacShaKeyFor(CLAVE_TEST.getBytes(StandardCharsets.UTF_8))).compact();
        for (String malo : List.of(sinFirma, sinFirma + ".", comoAdmin, otroUsuario, otraClave, caducado, otroEmisor,
                partes[0] + "." + partes[1] + "." + partes[2].substring(0, 10), "basura", "")) {
            mvc.perform(get("/api/me").header("Authorization", "Bearer " + malo))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.codigo").exists());
        }
        // El bueno sí entra; sin "Bearer" no.
        mvc.perform(get("/api/me").header("Authorization", "Bearer " + bueno)).andExpect(status().isOk());
        mvc.perform(get("/api/me").header("Authorization", bueno)).andExpect(status().isUnauthorized());
    }

    @Test
    void cuentaDesactivada_conTokenVigente_401AlMomento() throws Exception {
        String t = token("bea@test.com");
        bea.setActivo(false);
        mvc.perform(get("/api/me").header("Authorization", t)).andExpect(status().isUnauthorized());
    }

    // ---------- Fuerza bruta y enumeración ----------

    private ResultActions login(String email, String password) throws Exception {
        return mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("email", email, "password", password))));
    }

    @Test
    void emailInexistente_yContrasenaMala_mismaRespuesta() throws Exception {
        String a = login("nadie@test.com", "mala-mala-mala").andExpect(status().isUnauthorized())
                .andReturn().getResponse().getContentAsString();
        String b = login("ana@test.com", "mala-mala-mala").andExpect(status().isUnauthorized())
                .andReturn().getResponse().getContentAsString();
        assertThat(leer(a).get("codigo")).isEqualTo(leer(b).get("codigo"));
        assertThat(leer(a).get("mensaje")).isEqualTo(leer(b).get("mensaje"));
    }

    @Test
    void cambioDeContrasena_aLosCincoFallos_429() throws Exception {
        String t = token("ana@test.com");
        int ultimo = 0;
        for (int i = 0; i < 6; i++) {
            ultimo = mvc.perform(put("/api/me/password").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                            .content(json(Map.of("actual", "no-es-la-mia", "nueva", "Otra-larga-2026-x"))))
                    .andReturn().getResponse().getStatus();
        }
        assertThat(ultimo).isEqualTo(429);
    }

    // ---------- Asignación masiva ----------

    @Test
    void asignacionMasiva_rolYPropietario_seIgnoran() throws Exception {
        String t = token("bea@test.com");
        mvc.perform(patch("/api/me").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombre\":\"Bea\",\"rol\":\"ADMIN\",\"activo\":false,\"fechaBaja\":\"2020-01-01\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rol").value("PROPIETARIO"));
        mvc.perform(get("/api/usuarios").header("Authorization", token("bea@test.com"))).andExpect(status().isForbidden());
        mvc.perform(post("/api/pisos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"direccion\":\"Calle Bea 2\",\"idCiudad\":" + pisoAna.getCiudad().getId()
                                + ",\"numeroHabitaciones\":1,\"idPropietario\":" + ana.getId() + ",\"propietario\":{\"id\":" + ana.getId() + "}}"))
                .andExpect(status().isCreated());
        String deAna = mvc.perform(get("/api/pisos").header("Authorization", token("ana@test.com")))
                .andReturn().getResponse().getContentAsString();
        assertThat(deAna).doesNotContain("Calle Bea 2");
    }

    // ---------- CORS, cabeceras, actuator y errores ----------

    @Test
    void cors_ningunOrigenPermitido() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(get("/api/me").header("Authorization", t).header(HttpHeaders.ORIGIN, "https://malo.example"))
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
        mvc.perform(options("/api/me").header(HttpHeaders.ORIGIN, "https://malo.example")
                        .header(HttpHeaders.ACCESS_CONTROL_REQUEST_METHOD, "GET")
                        .header(HttpHeaders.ACCESS_CONTROL_REQUEST_HEADERS, "Authorization"))
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN))
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_CREDENTIALS));
        mvc.perform(post("/api/auth/login").header(HttpHeaders.ORIGIN, "https://malo.example").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "ana@test.com", "password", com.gestionap.api.Datos.PASSWORD))))
                .andExpect(header().doesNotExist(HttpHeaders.ACCESS_CONTROL_ALLOW_ORIGIN));
    }

    @Test
    void cabecerasDeSeguridad_enRespuestasBuenasYDeError() throws Exception {
        String t = token("ana@test.com");
        for (ResultActions r : List.of(mvc.perform(get("/api/pisos").header("Authorization", t)),
                mvc.perform(get("/api/pisos")), mvc.perform(get("/api/pisos/999999").header("Authorization", t)))) {
            r.andExpect(header().string("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; sandbox"))
                    .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                    .andExpect(header().string("X-Frame-Options", "DENY"))
                    .andExpect(header().string("Referrer-Policy", "no-referrer"))
                    .andExpect(header().string("Cache-Control", containsString("no-store")));
        }
    }

    @Test
    void actuator_soloSaludSinDetalles() throws Exception {
        mvc.perform(get("/actuator/health")).andExpect(status().isOk())
                .andExpect(content().json("{\"status\":\"UP\"}", org.springframework.test.json.JsonCompareMode.STRICT));
        datos.usuario("admin@test.com", Rol.ADMIN);
        String admin = token("admin@test.com");
        // El índice /actuator (con sesión) solo enlaza a health, igual que con Spring Boot 3.
        String indice = mvc.perform(get("/actuator").header("Authorization", admin)).andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        assertThat(leer(indice).get("_links").properties().stream().map(Map.Entry::getKey).toList()).containsExactlyInAnyOrder("self", "health", "health-path");
        mvc.perform(get("/actuator")).andExpect(status().isUnauthorized());
        for (String ruta : List.of("/actuator/env", "/actuator/beans", "/actuator/heapdump", "/actuator/info",
                "/actuator/configprops", "/actuator/mappings", "/actuator/loggers", "/actuator/health/liveness",
                "/actuator/health/db")) {
            int sin = mvc.perform(get(ruta)).andReturn().getResponse().getStatus();
            int con = mvc.perform(get(ruta).header("Authorization", admin)).andReturn().getResponse().getStatus();
            assertThat(sin).as(ruta).isIn(401, 404);
            assertThat(con).as(ruta + " como admin").isIn(403, 404);
        }
    }

    @Test
    void errores_sinTrazasNiDetallesInternos() throws Exception {
        String t = token("ana@test.com");
        for (ResultActions r : List.of(
                mvc.perform(post("/api/pisos").header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content("{no es json")),
                mvc.perform(get("/api/pisos/abc").header("Authorization", t)),
                mvc.perform(post("/api/gastos/1/factura").header("Authorization", t).contentType(MediaType.APPLICATION_JSON).content("{}")),
                mvc.perform(get("/api/no-existe").header("Authorization", t)))) {
            String cuerpo = r.andExpect(status().is4xxClientError()).andReturn().getResponse().getContentAsString();
            assertThat(cuerpo).doesNotContain("trace").doesNotContain("Exception").doesNotContain("at com.")
                    .doesNotContain("org.springframework").doesNotContain("SQL");
        }
    }
}
