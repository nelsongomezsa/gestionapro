package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.Rol;
import com.gestionap.api.repository.DispositivoRepository;
import com.gestionap.api.service.PushService;
import com.gestionap.api.service.RecordatoriosPago;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.lang.reflect.Method;
import java.time.LocalDate;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Push preparado pero sin credenciales de APNs en los tests: se registra el dispositivo y no se envía nada. */
class DispositivosPushTest extends IntegrationTest {

    static final String TOKEN = "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90";

    @Autowired DispositivoRepository dispositivos;
    @Autowired PushService push;
    @Autowired RecordatoriosPago recordatorios;

    @BeforeEach
    void preparar() {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);
        datos.usuario("bea@test.com", Rol.PROPIETARIO);
    }

    @Test
    void registrar_yReasignarAlCambiarDeUsuario_yBorrar() throws Exception {
        mvc.perform(post("/api/dispositivos").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("token", TOKEN))))
                .andExpect(status().isNoContent());
        // El mismo iPhone con otra cuenta: el token pasa a la nueva, sin duplicarse.
        mvc.perform(post("/api/dispositivos").header("Authorization", token("bea@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("token", TOKEN.toUpperCase()))))
                .andExpect(status().isNoContent());
        assertThat(dispositivos.findAll()).singleElement()
                .satisfies(d -> assertThat(d.getToken()).isEqualTo(TOKEN));
        // Ana ya no puede borrarlo; Bea sí.
        mvc.perform(delete("/api/dispositivos/" + TOKEN).header("Authorization", token("ana@test.com")));
        assertThat(dispositivos.count()).isEqualTo(1);
        mvc.perform(delete("/api/dispositivos/" + TOKEN).header("Authorization", token("bea@test.com")))
                .andExpect(status().isNoContent());
        assertThat(dispositivos.count()).isZero();
    }

    @Test
    void tokenNoValido() throws Exception {
        mvc.perform(post("/api/dispositivos").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("token", "no-es-un-token"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.codigo").value("TOKEN_NO_VALIDO"));
    }

    @Test
    void sinCredencialesDeApns_noEnvia_niGeneraAvisosPush() throws Exception {
        assertThat(push.configurado()).isFalse();
        push.enviar(1, "Título", "Texto");   // no hace nada y no falla
        assertThat(recordatorios.avisosConPush(LocalDate.now())).isZero();
    }

    @Test
    void cargaUtilDeApns() throws Exception {
        Method cuerpo = PushService.class.getDeclaredMethod("cuerpo", String.class, String.class);
        cuerpo.setAccessible(true);
        String json = (String) cuerpo.invoke(push, "Cobro vencido", "Lucía · 450,00 €");
        assertThat(json).contains("\"aps\"").contains("\"title\":\"Cobro vencido\"").contains("\"sound\":\"default\"");
    }
}
