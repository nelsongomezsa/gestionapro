package com.gestionap.api.web;

import com.gestionap.api.Datos;
import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.EstadoHabitacion;
import com.gestionap.api.domain.Rol;
import com.gestionap.api.domain.Usuario;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.InquilinoRepository;
import com.gestionap.api.repository.PagoRepository;
import com.gestionap.api.repository.UsuarioRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.time.LocalDate;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class EliminarCuentaIntegrationTest extends IntegrationTest {

    @Autowired UsuarioRepository usuarios;
    @Autowired InquilinoRepository inquilinos;
    @Autowired ContratoRepository contratos;
    @Autowired PagoRepository pagos;

    private org.springframework.test.web.servlet.ResultActions eliminar(String token, String password) throws Exception {
        return mvc.perform(delete("/api/me").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("password", password))));
    }

    @Test
    void inquilino_eliminaSuCuenta_seAnonimiza_yConservaContratoYPagos() throws Exception {
        Usuario ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        var hab = datos.habitacion(datos.piso("Calle 1", datos.ciudad("Madrid"), ana), 1, EstadoHabitacion.alquilada);
        var lucia = datos.inquilinoDe(ana, "11111111A");
        Usuario cuenta = datos.usuario("lucia@test.com", Rol.INQUILINO);
        cuenta.setDni("11111111A");
        cuenta.setIban("ES9121000418450200051332");
        lucia.setUsuario(cuenta);
        Contrato c = datos.contrato(hab, lucia, "450.00", LocalDate.now().minusMonths(2), LocalDate.now().plusMonths(10));
        datos.pago(c, "450.00", LocalDate.now().minusMonths(1));
        String t = token("lucia@test.com");

        eliminar(t, Datos.PASSWORD).andExpect(status().isNoContent());

        Usuario u = usuarios.findById(cuenta.getId()).orElseThrow();
        assertThat(u.getNombre()).isEqualTo("Usuario eliminado");
        assertThat(u.getEmail()).endsWith("@baja.invalid").doesNotContain("lucia");
        assertThat(u.getDni()).isNull();
        assertThat(u.getIban()).isNull();
        assertThat(u.isActivo()).isFalse();
        assertThat(u.getFechaBaja()).isNotNull();
        // La ficha del inquilino y su contrato y pagos siguen (los gestiona el propietario y la ley obliga a guardarlos).
        assertThat(inquilinos.findById(lucia.getId()).orElseThrow().getUsuario()).isNull();
        assertThat(contratos.findById(c.getId())).isPresent();
        assertThat(pagos.findAll()).isNotEmpty();
        // El token deja de valer y no se puede volver a entrar.
        mvc.perform(get("/api/me").header("Authorization", t)).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("email", "lucia@test.com", "password", Datos.PASSWORD))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void contrasenaIncorrecta_400_yAlQuintoFallo429() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);
        String t = token("ana@test.com");
        for (int i = 0; i < 5; i++) {
            eliminar(t, "otra-cosa").andExpect(status().isBadRequest()).andExpect(jsonPath("$.codigo").value("PASSWORD_INCORRECTA"));
        }
        eliminar(t, Datos.PASSWORD).andExpect(status().isTooManyRequests());
        assertThat(usuarios.findByEmail("ana@test.com")).isPresent();
    }

    @Test
    void sinContrasena_400() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);
        mvc.perform(delete("/api/me").header("Authorization", token("ana@test.com")).contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.codigo").value("VALIDACION"));
    }

    @Test
    void ultimoAdmin_noPuedeEliminarse_yUnaCuentaEliminadaNoSeReactiva() throws Exception {
        datos.usuario("jefe@test.com", Rol.ADMIN);
        eliminar(token("jefe@test.com"), Datos.PASSWORD).andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("ULTIMO_ADMIN"));

        Usuario bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        eliminar(token("bea@test.com"), Datos.PASSWORD).andExpect(status().isNoContent());
        mvc.perform(patch("/api/usuarios/" + bea.getId() + "/activo").header("Authorization", token("jefe@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(Map.of("activo", true))))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.codigo").value("CUENTA_ELIMINADA"));
    }

    @Test
    void cambiarContrasena_tambienTieneLimiteDeIntentos() throws Exception {
        datos.usuario("ana@test.com", Rol.PROPIETARIO);
        String t = token("ana@test.com");
        for (int i = 0; i < 5; i++) {
            mvc.perform(put("/api/me/password").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                            .content(json(Map.of("actual", "mala-1234", "nueva", "Otra-frase-segura-2026"))))
                    .andExpect(status().isBadRequest());
        }
        mvc.perform(put("/api/me/password").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("actual", Datos.PASSWORD, "nueva", "Otra-frase-segura-2026"))))
                .andExpect(status().isTooManyRequests());
    }
}
