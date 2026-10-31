package com.gestionap.api.web;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.Ciudad;
import com.gestionap.api.domain.DatosPiso;
import com.gestionap.api.domain.EstadoHabitacion;
import com.gestionap.api.domain.EstadoIncidencia;
import com.gestionap.api.domain.Habitacion;
import com.gestionap.api.domain.Incidencia;
import com.gestionap.api.domain.Inquilino;
import com.gestionap.api.domain.Piso;
import com.gestionap.api.domain.Rol;
import com.gestionap.api.domain.Usuario;
import com.gestionap.api.repository.GastoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class GastoIntegrationTest extends IntegrationTest {

    private final LocalDate hoy = LocalDate.now();
    private Piso piso;
    private Habitacion habitacion;
    private Incidencia incidencia;
    private String token;

    @org.springframework.beans.factory.annotation.Autowired
    private GastoRepository gastos;

    @BeforeEach
    void preparar() throws Exception {
        Ciudad ciudad = datos.ciudad("Madrid");
        Usuario ana = datos.usuario("ana-gastos@test.com", Rol.PROPIETARIO);
        piso = datos.piso("Calle gastos 1", ciudad, ana);
        habitacion = datos.habitacion(piso, 1, EstadoHabitacion.disponible);
        Inquilino inquilino = datos.inquilinoDe(ana, "22222222A");
        incidencia = datos.incidencia(habitacion, inquilino, "Grifo roto");
        token = token("ana-gastos@test.com");
    }

    private String gasto(String categoria, String importe) throws Exception {
        Map<String, Object> cuerpo = new HashMap<>();
        cuerpo.put("idPiso", piso.getId());
        cuerpo.put("idHabitacion", habitacion.getId());
        cuerpo.put("categoria", categoria);
        cuerpo.put("concepto", "Arreglo general");
        cuerpo.put("importe", importe);
        cuerpo.put("fecha", hoy.toString());
        cuerpo.put("deducible", true);
        return json(cuerpo);
    }

    @Test
    void creaListaYCalculaTotales() throws Exception {
        mvc.perform(post("/api/gastos").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
                        .content(gasto("IBI", "120.00")))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.tieneFactura").value(false));
        mvc.perform(get("/api/gastos?piso=" + piso.getId()).header("Authorization", token))
                .andExpect(jsonPath("$.lista.length()").value(1))
                .andExpect(jsonPath("$.total").value(120))
                .andExpect(jsonPath("$.totalDeducible").value(120));
    }

    @Test
    void respetaPropiedadYRolDeInquilino() throws Exception {
        Usuario bea = datos.usuario("bea-gastos@test.com", Rol.PROPIETARIO);
        Piso ajeno = datos.piso("Calle ajena 2", piso.getCiudad(), bea);
        String cuerpo = gasto("IBI", "12");
        mvc.perform(post("/api/gastos").header("Authorization", token("bea-gastos@test.com"))
                        .contentType(MediaType.APPLICATION_JSON).content(cuerpo))
                .andExpect(status().isNotFound());
        incidencia.setInquilino(datos.inquilino("33333333B", null));
        incidencia.getInquilino().setUsuario(datos.usuario("inquilino-gastos@test.com", Rol.INQUILINO));
        mvc.perform(get("/api/gastos?piso=" + ajeno.getId()).header("Authorization", token))
                .andExpect(status().isNotFound());
        mvc.perform(get("/api/gastos").header("Authorization", token("inquilino-gastos@test.com")))
                .andExpect(status().isForbidden());
    }

    @Test
    void sincronizaIncidenciaUnaVezYNoPermiteBorrarla() throws Exception {
        incidencia.setEstado(EstadoIncidencia.resuelta);
        incidencia.setCosteReparacion(new BigDecimal("75.00"));
        String url = "/api/gastos?piso=" + piso.getId();
        mvc.perform(get(url).header("Authorization", token)).andExpect(jsonPath("$.lista.length()").value(1));
        incidencia.setCosteReparacion(new BigDecimal("90.00"));
        mvc.perform(get(url).header("Authorization", token))
                .andExpect(jsonPath("$.lista.length()").value(1))
                .andExpect(jsonPath("$.lista[0].importe").value(90));
        Integer id = gastos.findByIdIncidencia(incidencia.getId()).orElseThrow().getId();
        mvc.perform(delete("/api/gastos/" + id).header("Authorization", token))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.codigo").value("GASTO_DE_INCIDENCIA"));
    }

    @Test
    void facturaPngSeDescargaYTxtSeRechaza() throws Exception {
        String respuesta = mvc.perform(post("/api/gastos").header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON).content(gasto("IBI", "50")))
                .andReturn().getResponse().getContentAsString();
        int id = com.fasterxml.jackson.databind.json.JsonMapper.builder().build().readTree(respuesta).get("id").asInt();
        byte[] png = FotosInventarioIntegrationTest.PNG;
        mvc.perform(multipart("/api/gastos/" + id + "/factura").file(new MockMultipartFile("archivo", "f.png", "image/png", png))
                        .header("Authorization", token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.tieneFactura").value(true));
        mvc.perform(get("/api/gastos/" + id + "/factura").header("Authorization", token))
                .andExpect(status().isOk()).andExpect(header().string("Content-Type", "image/png"))
                .andExpect(content().bytes(png));
        mvc.perform(multipart("/api/gastos/" + id + "/factura").file(new MockMultipartFile("archivo", "f.txt", "text/plain", new byte[]{1}))
                        .header("Authorization", token))
                .andExpect(status().isBadRequest());
    }

    @Test
    void metricasUsanIbiReal() throws Exception {
        DatosPiso financieros = new DatosPiso();
        financieros.setGastoIbiAnual(new BigDecimal("1000.00"));
        piso.setDatosFinancieros(financieros);
        mvc.perform(post("/api/gastos").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
                        .content(gasto("IBI", "120.00")))
                .andExpect(status().isCreated());
        mvc.perform(get("/api/pisos/" + piso.getId()).header("Authorization", token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.metricas.gastosReales").value(true))
                .andExpect(jsonPath("$.metricas.gastosAnuales").value(120));
    }
}
