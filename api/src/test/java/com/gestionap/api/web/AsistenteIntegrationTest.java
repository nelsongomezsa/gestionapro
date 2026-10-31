package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.ia.ModeloSimulado;
import com.gestionap.api.repository.ActividadRepository;
import com.gestionap.api.repository.PagoRepository;
import com.gestionap.api.service.ia.ModeloIA.Llamada;
import com.gestionap.api.web.dto.AsistenteDtos.ClasificacionIncidencia;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;

import java.time.LocalDate;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Asistente con el modelo simulado: nunca se llama a la API de Claude en los tests. */
class AsistenteIntegrationTest extends IntegrationTest {

    @Autowired ModeloSimulado modelo;
    @Autowired PagoRepository pagos;
    @Autowired ActividadRepository actividad;

    final LocalDate hoy = LocalDate.now();
    Usuario ana;
    Contrato deLucia;
    Contrato deBea;
    Habitacion habitacionDeAna;

    @BeforeEach
    void preparar() {
        modelo.reiniciar();
        ana = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Usuario bea = datos.usuario("bea@test.com", Rol.PROPIETARIO);
        Ciudad madrid = datos.ciudad("Madrid");
        habitacionDeAna = datos.habitacion(datos.piso("Calle de Ana 1", madrid, ana), 1, EstadoHabitacion.alquilada);
        Habitacion deBeaHab = datos.habitacion(datos.piso("Calle de Bea 2", madrid, bea), 1, EstadoHabitacion.alquilada);
        Inquilino lucia = datos.inquilinoDe(ana, "11111111A");
        lucia.setUsuario(datos.usuario("lucia@test.com", Rol.INQUILINO));
        deLucia = datos.contrato(habitacionDeAna, lucia, "450.00", hoy.minusMonths(3), hoy.plusMonths(9));
        deBea = datos.contrato(deBeaHab, datos.inquilinoDe(bea, "22222222B"), "400.00", hoy.minusMonths(3), hoy.plusMonths(9));
    }

    private String pregunta(String texto) throws Exception {
        return json(Map.of("mensaje", texto));
    }

    @Test
    void sinClave_estaDesactivado_conUnMensajeClaro() throws Exception {
        modelo.disponible = false;
        String t = token("ana@test.com");
        mvc.perform(get("/api/asistente/estado").header("Authorization", t))
                .andExpect(jsonPath("$.disponible").value(false))
                .andExpect(jsonPath("$.mensaje").value(org.hamcrest.Matchers.containsString("Falta la clave de la API de Claude")));
        mvc.perform(post("/api/asistente/conversar").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(pregunta("Hola")))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.codigo").value("ASISTENTE_DESACTIVADO"));
    }

    @Test
    void consultas_usanLosDatosDelUsuario_yNoLosDeOtros() throws Exception {
        modelo.planificadas.add(new Llamada("buscar_contratos", Map.of()));
        modelo.planificadas.add(new Llamada("cobros_del_mes", Map.of()));
        mvc.perform(post("/api/asistente/conversar").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(pregunta("¿Quién me debe este mes?")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.respuesta").value(org.hamcrest.Matchers.containsString("11111111A")))
                .andExpect(jsonPath("$.respuesta").value(org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("22222222B"))))
                .andExpect(jsonPath("$.acciones.length()").value(0))
                .andExpect(jsonPath("$.usadosHoy").value(1));
        assertThat(modelo.instruccionesRecibidas).contains("proponer_").contains("Hoy es");
        // Queda en Actividad, sin el texto de la conversación.
        assertThat(actividad.findAll()).anyMatch(a -> a.getAccion().equals("ASISTENTE_CONSULTA")
                && !a.getDescripcion().contains("debe"));
    }

    @Test
    void acciones_soloSeProponen_nuncaSeEjecutan() throws Exception {
        long antes = pagos.count();
        modelo.planificadas.add(new Llamada("proponer_pago", Map.of("idContrato", deLucia.getId(), "importe", 450)));
        modelo.planificadas.add(new Llamada("proponer_incidencia",
                Map.of("idHabitacion", habitacionDeAna.getId(), "descripcion", "Gotera en el baño")));
        modelo.planificadas.add(new Llamada("proponer_recordatorio", Map.of("idContrato", deLucia.getId())));
        mvc.perform(post("/api/asistente/conversar").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(pregunta("Registra el pago de Lucía")))
                .andExpect(jsonPath("$.acciones.length()").value(3))
                .andExpect(jsonPath("$.acciones[0].tipo").value("REGISTRAR_PAGO"))
                .andExpect(jsonPath("$.acciones[0].datos.idContrato").value(deLucia.getId()))
                .andExpect(jsonPath("$.acciones[0].datos.cantidad").value(450.00))
                .andExpect(jsonPath("$.acciones[1].tipo").value("CREAR_INCIDENCIA"))
                .andExpect(jsonPath("$.acciones[2].tipo").value("RECORDATORIO"))
                .andExpect(jsonPath("$.acciones[2].datos.texto").value(org.hamcrest.Matchers.containsString("450,00")));
        assertThat(pagos.count()).isEqualTo(antes);
    }

    @Test
    void accionSobreDatosAjenos_seRechaza_sinPropuesta() throws Exception {
        modelo.planificadas.add(new Llamada("proponer_pago", Map.of("idContrato", deBea.getId(), "importe", 400)));
        modelo.planificadas.add(new Llamada("proponer_pago", Map.of("idContrato", deLucia.getId(), "importe", -5)));
        mvc.perform(post("/api/asistente/conversar").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(pregunta("Registra el pago de Bea")))
                .andExpect(jsonPath("$.acciones.length()").value(0));
        assertThat(modelo.resultados).allMatch(r -> r.error());
    }

    @Test
    void falloDelServicioDeIA_llegaComoMensajeClaro() throws Exception {
        modelo.fallo = new com.gestionap.api.service.ia.ModeloIA.Fallo("El servicio de IA está recibiendo demasiadas consultas.", null);
        mvc.perform(post("/api/asistente/conversar").header("Authorization", token("ana@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(pregunta("Hola")))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.codigo").value("ASISTENTE_NO_RESPONDE"))
                .andExpect(jsonPath("$.mensaje").value(org.hamcrest.Matchers.containsString("demasiadas consultas")));
    }

    @Test
    void limiteDiario_porUsuario() throws Exception {
        String t = token("ana@test.com");
        for (int i = 0; i < 5; i++) {
            mvc.perform(post("/api/asistente/conversar").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                    .content(pregunta("Hola " + i))).andExpect(status().isOk());
        }
        mvc.perform(post("/api/asistente/conversar").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(pregunta("Una más")))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.codigo").value("LIMITE_ASISTENTE"));
        // Otro usuario tiene su propio límite.
        mvc.perform(post("/api/asistente/conversar").header("Authorization", token("bea@test.com"))
                .contentType(MediaType.APPLICATION_JSON).content(pregunta("Hola"))).andExpect(status().isOk());
    }

    @Test
    void clasificarIncidencia_yValoresFueraDeLaLista() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(post("/api/asistente/clasificar-incidencia").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("descripcion", "Sale agua por debajo del lavabo"))))
                .andExpect(jsonPath("$.categoria").value("FONTANERIA"))
                .andExpect(jsonPath("$.urgencia").value("ALTA"));
        modelo.extraccion = new ClasificacionIncidencia("INVENTADA", "MUY ALTA", "x");
        mvc.perform(post("/api/asistente/clasificar-incidencia").header("Authorization", t).contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("descripcion", "Algo raro"))))
                .andExpect(jsonPath("$.categoria").value("OTROS"))
                .andExpect(jsonPath("$.urgencia").value("MEDIA"));
    }

    @Test
    void leerFactura_soloFotos_yProponeElGasto() throws Exception {
        String t = token("ana@test.com");
        mvc.perform(multipart("/api/asistente/leer-factura")
                        .file(new MockMultipartFile("archivo", "f.png", "image/png", FotosInventarioIntegrationTest.PNG))
                        .header("Authorization", t))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.importe").value(145.20))
                .andExpect(jsonPath("$.categoria").value("REPARACION"));
        mvc.perform(multipart("/api/asistente/leer-factura")
                        .file(new MockMultipartFile("archivo", "f.txt", "text/plain", "hola".getBytes()))
                        .header("Authorization", t))
                .andExpect(jsonPath("$.codigo").value("TIPO_NO_ADMITIDO"));
    }

    @Test
    void elInquilinoNoUsaElAsistente() throws Exception {
        mvc.perform(get("/api/asistente/estado").header("Authorization", token("lucia@test.com"))).andExpect(status().isForbidden());
    }
}
