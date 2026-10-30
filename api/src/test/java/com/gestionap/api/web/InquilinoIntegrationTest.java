package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class InquilinoIntegrationTest extends IntegrationTest {

    Usuario ana;
    Usuario bea;
    Inquilino conContrato;
    Inquilino deBea;
    Contrato contrato;

    @BeforeEach
    void preparar() {
        Ciudad madrid = datos.ciudad("Madrid");
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        datos.usuario("admin@test.com", Rol.ADMIN);
        Piso pisoAna = datos.piso("Calle de Ana 1", madrid, ana);
        Habitacion h = datos.habitacion(pisoAna, 3, EstadoHabitacion.alquilada);
        // Contrato en un piso de Ana, pero el inquilino lo dio de alta el escritorio (sin propietario).
        conContrato = datos.inquilino("11111111A", "lucia@test.com");
        contrato = datos.contratoActivo(h, conContrato, "450.00");
        datos.pago(contrato, "450.00", LocalDate.now().minusMonths(1));
        datos.pago(contrato, "450.00", LocalDate.now());
        deBea = datos.inquilinoDe(bea, "22222222B");
    }

    private Map<String, Object> inquilino(String dni) {
        Map<String, Object> m = new HashMap<>();
        m.put("nombre", "Marta");
        m.put("apellidos", "López Ruiz");
        m.put("dni", dni);
        m.put("telefono", "+34600111222");
        m.put("email", "marta@test.com");
        return m;
    }

    @Test
    void propietario_veLosDeSusContratos_noLosDeOtros() throws Exception {
        mvc.perform(get("/api/inquilinos").header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].dni").value("11111111A"))
                .andExpect(jsonPath("$[0].contratoActivo.numeroHabitacion").value(3))
                .andExpect(jsonPath("$[0].contratoActivo.vencimiento").value("NORMAL"))
                .andExpect(jsonPath("$[0].tieneCuentaApp").value(false));
        mvc.perform(get("/api/inquilinos/" + deBea.getId()).header("Authorization", token("ana@test.com")))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/inquilinos").header("Authorization", token("admin@test.com")))
                .andExpect(jsonPath("$.length()").value(2));
    }

    @Test
    void ficha_conContratosYPagos() throws Exception {
        mvc.perform(get("/api/inquilinos/" + conContrato.getId()).header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.contratos.length()").value(1))
                .andExpect(jsonPath("$.contratos[0].activo").value(true))
                .andExpect(jsonPath("$.contratos[0].piso.direccion").value("Calle de Ana 1"))
                .andExpect(jsonPath("$.pagos.length()").value(2))
                .andExpect(jsonPath("$.pagos[0].fechaPago").value(LocalDate.now().toString()));
    }

    @Test
    void crear_quedaComoSuyo_aunqueNoTengaContrato() throws Exception {
        String t = token("bea@test.com");
        String cuerpo = mvc.perform(post("/api/inquilinos").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(inquilino("33333333c"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.dni").value("33333333C"))
                .andReturn().getResponse().getContentAsString();
        int id = leer(cuerpo).get("id").asInt();

        mvc.perform(get("/api/inquilinos").header("Authorization", t))
                .andExpect(jsonPath("$.length()").value(2));
        mvc.perform(get("/api/inquilinos/" + id).header("Authorization", token("ana@test.com")))
                .andExpect(status().isNotFound());
        // Y puede invitarlo a la app aunque aún no tenga contrato.
        mvc.perform(post("/api/inquilinos/" + id + "/invitaciones").header("Authorization", t))
                .andExpect(status().isCreated());
    }

    @Test
    void validacion_comoElEscritorio_masNie() throws Exception {
        String t = token("ana@test.com");
        var malo = inquilino("1234");
        malo.put("telefono", "12");
        malo.put("email", "no-es-email");
        mvc.perform(post("/api/inquilinos").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(malo)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errores.length()").value(3));
        mvc.perform(post("/api/inquilinos").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(inquilino("X1234567L"))))
                .andExpect(status().isCreated());
        // Los datos de demo guardan los teléfonos con espacios ("633 456 789").
        var conEspacios = inquilino("Y1234567X");
        conEspacios.put("telefono", "633 456 789");
        mvc.perform(post("/api/inquilinos").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(conEspacios)))
                .andExpect(status().isCreated());
    }

    @Test
    void dniDuplicado_409() throws Exception {
        mvc.perform(post("/api/inquilinos").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(json(inquilino("22222222B"))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("DNI_DUPLICADO"));
    }

    @Test
    void editar_yBorrar() throws Exception {
        String t = token("bea@test.com");
        var cambio = inquilino("22222222B");
        cambio.put("nombre", "Beatriz");
        mvc.perform(put("/api/inquilinos/" + deBea.getId()).header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content(json(cambio)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nombre").value("Beatriz"));
        mvc.perform(delete("/api/inquilinos/" + deBea.getId()).header("Authorization", t))
                .andExpect(status().isNoContent());
    }

    @Test
    void borrarConContrato_409() throws Exception {
        mvc.perform(delete("/api/inquilinos/" + conContrato.getId()).header("Authorization", token("ana@test.com")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("INQUILINO_CON_HISTORIAL"));
    }

    @Test
    void qrPago_sinIban_409ConIndicacion() throws Exception {
        mvc.perform(get("/api/inquilinos/" + conContrato.getId() + "/qr-pago").header("Authorization", token("ana@test.com")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("IBAN_NO_CONFIGURADO"))
                .andExpect(jsonPath("$.mensaje").value(containsString("Perfil")));
    }

    @Test
    void qrPago_conIban_usaLosDatosDelPropietario() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(patch("/api/me").header("Authorization", t)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"iban\":\"es91 2100 0418 4502 0005 1332\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.iban").value("ES91 2100 0418 4502 0005 1332"));

        mvc.perform(get("/api/inquilinos/" + conContrato.getId() + "/qr-pago").header("Authorization", t))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.beneficiario").value("Usuario ana@test.com"))
                .andExpect(jsonPath("$.importe").value(450.00))
                .andExpect(jsonPath("$.concepto").value(startsWith("Alquiler Hab.3 Ana García 11111111A ")))
                .andExpect(jsonPath("$.payload").value(startsWith("BCD\n002\n1\nSCT\n\nUsuario ana@test.com\nES9121000418450200051332\nEUR450.00\n")));
    }

    @Test
    void qrPago_sinContratoActivo_409() throws Exception {
        mvc.perform(get("/api/inquilinos/" + deBea.getId() + "/qr-pago").header("Authorization", token("bea@test.com")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("SIN_CONTRATO_ACTIVO"));
    }
}
