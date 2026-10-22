package com.gestionap.api.security;

import com.gestionap.api.domain.Rol;
import com.gestionap.api.domain.Usuario;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;

class JwtServiceTest {

    private static final String SECRETO = "test-secret-gestionapro-api-solo-para-tests-0123456789";

    private final JwtService jwt = new JwtService(new JwtProperties(SECRETO, Duration.ofHours(1)));

    private static String token(JwtService servicio, int idUsuario) {
        Usuario u = new Usuario();
        u.setId(idUsuario);
        u.setRol(Rol.PROPIETARIO);
        return servicio.generar(u).valor();
    }

    @Test
    void tokenValido_devuelveElIdDelUsuario() {
        assertThat(jwt.validar(token(jwt, 7))).contains(7);
    }

    @Test
    void payloadModificado_paraSuplantarOtroUsuario_seRechaza() {
        String[] partes = token(jwt, 7).split("\\.");
        Base64.Decoder dec = Base64.getUrlDecoder();
        String payload = new String(dec.decode(partes[1]), StandardCharsets.UTF_8).replace("\"sub\":\"7\"", "\"sub\":\"1\"");
        String falso = partes[0] + "." + Base64.getUrlEncoder().withoutPadding()
                .encodeToString(payload.getBytes(StandardCharsets.UTF_8)) + "." + partes[2];

        assertThat(jwt.validar(falso)).isEmpty();
    }

    @Test
    void firmaAlterada_seRechaza() {
        String t = token(jwt, 7);
        int i = t.lastIndexOf('.') + 10;
        String alterado = t.substring(0, i) + (t.charAt(i) == 'A' ? 'B' : 'A') + t.substring(i + 1);

        assertThat(jwt.validar(alterado)).isEmpty();
    }

    @Test
    void firmadoConOtraClave_seRechaza() {
        var otro = new JwtService(new JwtProperties("otra-clave-distinta-de-al-menos-32-caracteres-xx", Duration.ofHours(1)));

        assertThat(jwt.validar(token(otro, 7))).isEmpty();
    }

    @Test
    void tokenCaducado_seRechaza() {
        var caducado = new JwtService(new JwtProperties(SECRETO, Duration.ofSeconds(-5)));

        assertThat(jwt.validar(token(caducado, 7))).isEmpty();
    }

    @Test
    void basura_seRechazaSinExcepcion() {
        assertThat(jwt.validar("no-es-un-jwt")).isEmpty();
        assertThat(jwt.validar("")).isEmpty();
    }
}
