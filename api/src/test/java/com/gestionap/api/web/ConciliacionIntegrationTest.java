package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;

import java.time.LocalDate;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class ConciliacionIntegrationTest extends IntegrationTest {
    LocalDate hoy = LocalDate.now();
    Usuario ana;
    Usuario bea;
    Contrato contrato;

    @BeforeEach
    void preparar() {
        Ciudad ciudad = datos.ciudad("Madrid");
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        var piso = datos.piso("Calle Mayor 1", ciudad, ana);
        var habitacion = datos.habitacion(piso, 2, EstadoHabitacion.alquilada);
        Inquilino inquilino = datos.inquilinoDe(ana, "11111111A");
        inquilino.setNombre("Lucía");
        inquilino.setApellidos("Pérez");
        contrato = datos.contrato(habitacion, inquilino, "450.00", hoy.minusMonths(2), hoy.plusMonths(4));
        var pisoAjeno = datos.piso("Otra 2", ciudad, bea);
        datos.contrato(datos.habitacion(pisoAjeno, 1, EstadoHabitacion.alquilada),
                datos.inquilinoDe(bea, "22222222B"), "400.00", hoy.minusMonths(2), hoy.plusMonths(4));
    }

    private MockMultipartFile csv(String concepto, String importe) {
        String contenido = "Fecha;Concepto;Importe\n" + hoy + ";" + concepto + ";" + importe;
        return new MockMultipartFile("archivo", "extracto.csv", "text/csv", contenido.getBytes());
    }

    @Test
    void proponePorNombreEImporteYSeñalaPagoExistente() throws Exception {
        String token = token("ana@test.com");
        mvc.perform(multipart("/api/conciliacion/analizar").file(csv("Transferencia Lucia Perez", "450,00"))
                        .header("Authorization", token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.propuestas[0].propuesta.confianza").value("ALTA"));
        datos.pago(contrato, "450.00", hoy);
        mvc.perform(multipart("/api/conciliacion/analizar").file(csv("Transferencia", "450,00"))
                        .header("Authorization", token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.propuestas[0].propuesta.yaRegistrado").value(true));
    }

    @Test
    void bajaSinCoincidenciasYNoExponeContratosAjeno() throws Exception {
        mvc.perform(multipart("/api/conciliacion/analizar").file(csv("Pago desconocido", "12,34"))
                        .header("Authorization", token("ana@test.com")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.propuestas[0].propuesta.confianza").value("BAJA"));
        mvc.perform(multipart("/api/conciliacion/analizar").file(csv("Pago", "400,00"))
                        .header("Authorization", token("ana@test.com")))
                .andExpect(jsonPath("$.propuestas").isArray())
                .andExpect(jsonPath("$.propuestas.length()").value(1))
                .andExpect(jsonPath("$.propuestas[0].propuesta.inquilino").value("Lucía Pérez"));
    }

    @Test
    void confirmaCreaReciboYRechazaDuplicado() throws Exception {
        String payload = json(Map.of("pagos", java.util.List.of(Map.of("idContrato", contrato.getId(),
                "fecha", hoy.toString(), "importe", "450.00", "metodoPago", "transferencia"))));
        mvc.perform(post("/api/conciliacion/confirmar").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isOk()).andExpect(jsonPath("$.pagos[0].recibo").exists());
        mvc.perform(post("/api/conciliacion/confirmar").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isConflict());
    }

    @Test
    void inquilinoNoPuedeAnalizar() throws Exception {
        contrato.getInquilino().setUsuario(datos.usuario("lucia@test.com", Rol.INQUILINO));
        mvc.perform(multipart("/api/conciliacion/analizar").file(csv("Transferencia", "450,00"))
                        .header("Authorization", token("lucia@test.com")))
                .andExpect(status().isForbidden());
    }
}
