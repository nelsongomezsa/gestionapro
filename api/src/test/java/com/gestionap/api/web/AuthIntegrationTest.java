package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.Rol;
import com.gestionap.api.repository.UsuarioRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class AuthIntegrationTest extends IntegrationTest {

    @Autowired UsuarioRepository usuarios;

    @Test
    void login_correcto_devuelveTokenYElRolTraducido() throws Exception {
        datos.usuario("gestor@test.com", Rol.PROPIETARIO);

        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "  GESTOR@test.com ", "password", "secreta123"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tipo").value("Bearer"))
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.usuario.rol").value("PROPIETARIO"));
    }

    @Test
    void login_passwordIncorrecta_es401ConFormatoDeError() throws Exception {
        datos.usuario("gestor@test.com", Rol.PROPIETARIO);

        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "gestor@test.com", "password", "otra"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.status").value(401))
                .andExpect(jsonPath("$.codigo").value("CREDENCIALES_INCORRECTAS"))
                .andExpect(jsonPath("$.path").value("/api/auth/login"));
    }

    @Test
    void login_usuarioDesactivado_es401() throws Exception {
        var u = datos.usuario("baja@test.com", Rol.PROPIETARIO);
        u.setActivo(false);

        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "baja@test.com", "password", "secreta123"))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void login_conHashSha256Antiguo_entraYLoRehasheaABcrypt() throws Exception {
        // SHA-256 hex de "secreta123", como los usuarios antiguos del escritorio.
        String sha = java.util.HexFormat.of().formatHex(
                java.security.MessageDigest.getInstance("SHA-256").digest("secreta123".getBytes()));
        var u = datos.usuarioConHash("antiguo@test.com", Rol.ADMIN, sha);

        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "antiguo@test.com", "password", "secreta123"))))
                .andExpect(status().isOk());

        assertThat(usuarios.findById(u.getId()).orElseThrow().getPasswordHash()).startsWith("$2");
        assertThat(usuarios.findById(u.getId()).orElseThrow().isDebeCambiarPassword()).isTrue();
    }

    @Test
    void passwordCaducada_soloDejaVerElPerfilYCambiarla_yAlCambiarlaSeLibera() throws Exception {
        var u = datos.usuario("caducada@test.com", Rol.PROPIETARIO);
        u.setDebeCambiarPassword(true);
        String t = token("caducada@test.com");

        mvc.perform(get("/api/pisos").header("Authorization", t))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.codigo").value("PASSWORD_CADUCADA"));
        mvc.perform(get("/api/me").header("Authorization", t))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.debeCambiarPassword").value(true));

        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/me/password")
                        .header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("actual", "secreta123", "nueva", "Nueva-frase-segura-2026"))))
                .andExpect(status().is2xxSuccessful());

        mvc.perform(get("/api/pisos").header("Authorization", t)).andExpect(status().isOk());
        mvc.perform(get("/api/me").header("Authorization", t))
                .andExpect(jsonPath("$.debeCambiarPassword").doesNotExist());
    }

    @Test
    void login_sinCampos_es400ConErroresPorCampo() throws Exception {
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("VALIDACION"))
                .andExpect(jsonPath("$.errores.length()").value(2));
    }

    @Test
    void me_sinToken_es401EnJson() throws Exception {
        mvc.perform(get("/api/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.codigo").value("NO_AUTENTICADO"));
    }

    @Test
    void me_conFirmaAlterada_es401() throws Exception {
        datos.usuario("gestor@test.com", Rol.PROPIETARIO);
        String token = token("gestor@test.com");

        String falso = token.substring(0, token.length() - 12) + "AAAAAAAAAAAA";
        mvc.perform(get("/api/me").header("Authorization", falso))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void me_devuelveElUsuarioAutenticado() throws Exception {
        datos.usuario("gestor@test.com", Rol.PROPIETARIO);

        mvc.perform(get("/api/me").header("Authorization", token("gestor@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("gestor@test.com"))
                .andExpect(jsonPath("$.rol").value("PROPIETARIO"))
                .andExpect(jsonPath("$.idInquilino").doesNotExist());
    }

    @Test
    void usuarioDesactivadoTrasElLogin_pierdeElAccesoAunqueElTokenNoHayaCaducado() throws Exception {
        var u = datos.usuario("gestor@test.com", Rol.PROPIETARIO);
        String token = token("gestor@test.com");
        u.setActivo(false);
        usuarios.flush();

        mvc.perform(get("/api/me").header("Authorization", token))
                .andExpect(status().isUnauthorized());
    }
}
