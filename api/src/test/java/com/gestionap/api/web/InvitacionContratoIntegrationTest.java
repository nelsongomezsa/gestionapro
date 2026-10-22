package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.repository.InvitacionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.time.LocalDateTime;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.matchesPattern;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class InvitacionContratoIntegrationTest extends IntegrationTest {

    @Autowired InvitacionRepository invitaciones;

    Inquilino lucia;
    Contrato contratoLucia;
    Contrato contratoOtro;

    @BeforeEach
    void preparar() {
        Ciudad sevilla = datos.ciudad("Sevilla");
        Usuario ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        ana.setDni("12345678Z");
        Usuario bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        Piso pisoAna = datos.piso("Calle Feria 10", sevilla, ana);
        Piso pisoBea = datos.piso("Calle Betis 3", sevilla, bea);

        lucia = datos.inquilino("44444444D", null);
        contratoLucia = datos.contratoActivo(datos.habitacion(pisoAna, 1, EstadoHabitacion.alquilada), lucia, "420.00");
        contratoOtro = datos.contratoActivo(datos.habitacion(pisoBea, 1, EstadoHabitacion.alquilada),
                datos.inquilino("55555555E", null), "380.00");
    }

    private String invitar(String tokenPropietario, int idInquilino) throws Exception {
        String cuerpo = mvc.perform(post("/api/inquilinos/" + idInquilino + "/invitaciones")
                        .header("Authorization", tokenPropietario))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.codigo").value(matchesPattern("[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}")))
                .andExpect(jsonPath("$.emailEnviado").value(false))
                .andReturn().getResponse().getContentAsString();
        return leer(cuerpo).get("codigo").asText();
    }

    private org.springframework.test.web.servlet.ResultActions registrar(String codigo, String email) throws Exception {
        return mvc.perform(post("/api/auth/register-inquilino").contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("codigo", codigo, "email", email, "password", "clave-segura-1"))));
    }

    @Test
    void flujoCompleto_invitar_registrar_yVerSoloSuContrato() throws Exception {
        String codigo = invitar(token("ana@test.com"), lucia.getId());

        // Minúsculas y sin guiones: se teclea a mano en el móvil.
        String cuerpo = registrar(codigo.toLowerCase().replace("-", ""), "lucia@test.com")
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.usuario.rol").value("INQUILINO"))
                .andExpect(jsonPath("$.usuario.idInquilino").value(lucia.getId()))
                .andReturn().getResponse().getContentAsString();
        String tokenLucia = "Bearer " + leer(cuerpo).get("token").asText();

        mvc.perform(get("/api/me").header("Authorization", tokenLucia))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nombre").value(lucia.getNombreCompleto()))
                .andExpect(jsonPath("$.idInquilino").value(lucia.getId()));

        byte[] pdf = mvc.perform(get("/api/contratos/" + contratoLucia.getId() + "/pdf").header("Authorization", tokenLucia))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_PDF))
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(new String(pdf, 0, 5)).isEqualTo("%PDF-");

        mvc.perform(get("/api/contratos/" + contratoOtro.getId() + "/pdf").header("Authorization", tokenLucia))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/pisos").header("Authorization", tokenLucia))
                .andExpect(status().isForbidden());
    }

    @Test
    void codigo_esDeUnSoloUso() throws Exception {
        String codigo = invitar(token("ana@test.com"), lucia.getId());
        registrar(codigo, "lucia@test.com").andExpect(status().isCreated());

        registrar(codigo, "otra@test.com")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("INVITACION_NO_VALIDA"));
    }

    @Test
    void codigoCaducado_seRechaza() throws Exception {
        String codigo = invitar(token("ana@test.com"), lucia.getId());
        invitaciones.findAll().forEach(i -> i.setFechaExpiracion(LocalDateTime.now().minusMinutes(1)));

        registrar(codigo, "lucia@test.com")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("INVITACION_NO_VALIDA"));
    }

    @Test
    void nuevaInvitacion_anulaLaAnterior() throws Exception {
        String t = token("ana@test.com");
        String primero = invitar(t, lucia.getId());
        String segundo = invitar(t, lucia.getId());

        registrar(primero, "lucia@test.com").andExpect(status().isBadRequest());
        registrar(segundo, "lucia@test.com").andExpect(status().isCreated());
    }

    @Test
    void codigoInventado_seRechaza() throws Exception {
        registrar("AAAA-BBBB-CCCC", "x@test.com")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("INVITACION_NO_VALIDA"));
    }

    @Test
    void emailYaUsado_es409_yLaInvitacionSigueSinUsar() throws Exception {
        String codigo = invitar(token("ana@test.com"), lucia.getId());

        registrar(codigo, "bea@test.com")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("EMAIL_EN_USO"));
        assertThat(invitaciones.findAll()).allMatch(i -> i.getFechaUso() == null);
    }

    @Test
    void propietario_noPuedeInvitarAInquilinosDeOtro() throws Exception {
        mvc.perform(post("/api/inquilinos/" + contratoOtro.getInquilino().getId() + "/invitaciones")
                        .header("Authorization", token("ana@test.com")))
                .andExpect(status().isNotFound());
    }

    @Test
    void inquilinoYaRegistrado_noAdmiteMasInvitaciones() throws Exception {
        String t = token("ana@test.com");
        registrar(invitar(t, lucia.getId()), "lucia@test.com").andExpect(status().isCreated());

        mvc.perform(post("/api/inquilinos/" + lucia.getId() + "/invitaciones").header("Authorization", t))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("INQUILINO_YA_REGISTRADO"));
    }

    @Test
    void la_BD_guardaElHashDelCodigo_noElCodigo() throws Exception {
        String codigo = invitar(token("ana@test.com"), lucia.getId());

        assertThat(invitaciones.findAll()).singleElement()
                .satisfies(i -> assertThat(i.getCodigoHash()).hasSize(64).doesNotContain(codigo.replace("-", "")));
    }

    @Test
    void pdf_propietarioDelPiso_si_otroPropietario_no() throws Exception {
        mvc.perform(get("/api/contratos/" + contratoLucia.getId() + "/pdf").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.containsString("Contrato_Ana_")));
        mvc.perform(get("/api/contratos/" + contratoLucia.getId() + "/pdf").header("Authorization", token("bea@test.com")))
                .andExpect(status().isNotFound());
    }
}
