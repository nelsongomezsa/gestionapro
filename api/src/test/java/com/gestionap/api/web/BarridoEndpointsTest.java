package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.mvc.method.RequestMappingInfo;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.request;

/**
 * Barrido de todos los endpoints de la API: sin token, con token manipulado, con cada rol, con ids
 * inexistentes y con cuerpos vacíos. Comprueba que nada responde 500 ni deja pasar sin autenticación;
 * con {@code -Dsnapshots} sus respuestas forman parte de la referencia JSON.
 */
class BarridoEndpointsTest extends IntegrationTest {

    private static final String NO_EXISTE = "999999";

    @Autowired @Qualifier("requestMappingHandlerMapping")
    RequestMappingHandlerMapping mappings;

    Usuario ana;
    Piso piso;
    Habitacion hab;
    Inquilino lucia;
    Contrato contrato;
    Pago pago;
    Incidencia incidencia;

    @BeforeEach
    void preparar() {
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        datos.usuario("bea@test.com", Rol.PROPIETARIO);
        datos.usuario("admin@test.com", Rol.ADMIN);
        piso = datos.piso("Calle Mayor 1", datos.ciudad("Madrid"), ana);
        hab = datos.habitacion(piso, 1, EstadoHabitacion.alquilada);
        lucia = datos.inquilinoDe(ana, "11111111H");
        lucia.setUsuario(datos.usuario("lucia@test.com", Rol.INQUILINO));
        contrato = datos.contrato(hab, lucia, "450.00", LocalDate.of(2026, 1, 1), LocalDate.of(2027, 12, 31));
        pago = datos.pago(contrato, "450.00", LocalDate.of(2026, 2, 3));
        incidencia = datos.incidencia(hab, lucia, "Grifo que gotea");
    }

    /** Endpoints «METODO /ruta», ordenados (los de springdoc y /error no son de la API). */
    private List<String[]> endpoints() {
        TreeSet<String> todos = new TreeSet<>();
        for (Map.Entry<RequestMappingInfo, HandlerMethod> e : mappings.getHandlerMethods().entrySet()) {
            if (!e.getValue().getBeanType().getPackageName().startsWith("com.gestionap")) continue;
            for (String ruta : e.getKey().getPatternValues()) {
                for (var m : e.getKey().getMethodsCondition().getMethods()) todos.add(m.name() + " " + ruta);
            }
        }
        List<String[]> lista = new ArrayList<>();
        for (String s : todos) lista.add(s.split(" ", 2));
        return lista;
    }

    private static String rellenar(String ruta, String id) {
        return ruta.replace("{formato:pdf|csv}", "csv").replace("{parte}", "inquilino")
                .replace("{token}", "token-inexistente").replaceAll("\\{[^}]+}", id);
    }

    /** Id real del recurso de la ruta (para las lecturas con datos), o el inexistente. */
    private String idReal(String ruta) {
        if (ruta.startsWith("/api/pisos/{id}")) return piso.getId().toString();
        if (ruta.startsWith("/api/habitaciones/{id}")) return hab.getId().toString();
        if (ruta.startsWith("/api/contratos/{id}")) return contrato.getId().toString();
        if (ruta.startsWith("/api/inquilinos/{id}")) return lucia.getId().toString();
        if (ruta.startsWith("/api/pagos/{id}")) return pago.getId().toString();
        if (ruta.startsWith("/api/incidencias/{id}")) return incidencia.getId().toString();
        return NO_EXISTE;
    }

    /** Parámetros obligatorios, y un mes fijo donde el resultado depende del mes en curso. */
    private static String parametros(String ruta) {
        return switch (ruta) {
            case "/api/buscar" -> "?q=Mayor";
            case "/api/estadisticas/analisis" -> "?desde=2026-01-01&hasta=2026-12-31";
            case "/api/pisos/{id}/resumen-fiscal", "/api/pisos/{id}/resumen-fiscal/{formato:pdf|csv}" -> "?anio=2026";
            case "/api/pagos", "/api/pagos/resumen", "/api/calendario", "/api/informes/mensual" -> "?mes=2026-02";
            default -> "";
        };
    }

    private int llamar(String metodo, String ruta, String token, boolean conCuerpo) throws Exception {
        MockHttpServletRequestBuilder r = request(HttpMethod.valueOf(metodo), ruta);
        if (token != null) r.header("Authorization", token);
        if (conCuerpo && !metodo.equals("GET") && !metodo.equals("DELETE")) {
            r.contentType(MediaType.APPLICATION_JSON).content("{}");
        }
        return mvc.perform(r).andReturn().getResponse().getStatus();
    }

    private static boolean publico(String ruta) {
        return ruta.startsWith("/api/auth/");
    }

    /** Quitarse la cuenta corta el resto del barrido: lo cubre EliminarCuentaIntegrationTest. */
    private static boolean seSalta(String metodo, String ruta) {
        return metodo.equals("DELETE") && ruta.equals("/api/me");
    }

    @Test
    void sinToken_401EnTodoLoQueNoEsPublico() throws Exception {
        for (String[] e : endpoints()) {
            int s = llamar(e[0], rellenar(e[1], NO_EXISTE), null, true);
            if (!publico(e[1])) assertThat(s).as(e[0] + " " + e[1]).isEqualTo(401);
            assertThat(s).as(e[0] + " " + e[1]).isLessThan(500);
        }
    }

    @Test
    void tokenManipulado_401() throws Exception {
        String bueno = token("ana@test.com");
        String malo = bueno.substring(0, bueno.length() - 4) + (bueno.endsWith("AAAA") ? "BBBB" : "AAAA");
        for (String[] e : endpoints()) {
            if (publico(e[1])) continue;
            assertThat(llamar(e[0], rellenar(e[1], NO_EXISTE), malo, true)).as(e[0] + " " + e[1]).isEqualTo(401);
        }
    }

    @Test
    void inquilino_noLlegaALoDelPropietario() throws Exception {
        String t = token("lucia@test.com");
        for (String[] e : endpoints()) {
            if (seSalta(e[0], e[1])) continue;
            assertThat(llamar(e[0], rellenar(e[1], NO_EXISTE), t, true)).as(e[0] + " " + e[1]).isLessThan(500);
        }
    }

    @Test
    void propietarioYAdmin_idsInexistentesYCuerposVacios() throws Exception {
        for (String email : List.of("bea@test.com", "admin@test.com")) {
            String t = token(email);
            for (String[] e : endpoints()) {
                if (seSalta(e[0], e[1])) continue;
                assertThat(llamar(e[0], rellenar(e[1], NO_EXISTE), t, true)).as(email + " " + e[0] + " " + e[1]).isLessThan(500);
            }
        }
    }

    /** Todas las lecturas con datos reales: el dueño, otro propietario (IDOR), el admin y el inquilino. */
    @Test
    void lecturas_conDatos_cadaRol() throws Exception {
        for (String email : List.of("ana@test.com", "bea@test.com", "admin@test.com", "lucia@test.com")) {
            String t = token(email);
            for (String[] e : endpoints()) {
                if (!e[0].equals("GET")) continue;
                String ruta = rellenar(e[1], idReal(e[1])) + parametros(e[1]);
                int s = llamar("GET", ruta, t, false);
                assertThat(s).as(email + " GET " + ruta).isLessThan(500);
                if (email.equals("bea@test.com") && !ruta.contains(NO_EXISTE) && e[1].contains("{")) {
                    assertThat(s).as("IDOR " + ruta).isIn(403, 404);
                }
            }
        }
    }
}
