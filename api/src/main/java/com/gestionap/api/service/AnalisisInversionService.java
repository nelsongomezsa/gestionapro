package com.gestionap.api.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.gestionap.api.domain.AnalisisInversion;
import com.gestionap.api.repository.AnalisisInversionRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.AnalisisInversionDtos.AnalisisInversionRequest;
import com.gestionap.api.web.dto.AnalisisInversionDtos.AnalisisInversionResponse;
import com.gestionap.api.web.dto.RentabilidadRequest;
import com.gestionap.api.web.dto.RentabilidadResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Stream;

/**
 * Análisis de inversión guardados: cada usuario ve, cambia y borra solo los suyos (también el
 * admin). Se guarda la entrada de la calculadora y el resultado se recalcula al leer.
 */
@Service
public class AnalisisInversionService {

    public static final int MAXIMO_POR_USUARIO = 50;
    /** Ningún importe de la calculadora pasa de 100 millones: por encima es un error de tecleo. */
    static final double IMPORTE_MAXIMO = 100_000_000;

    private final AnalisisInversionRepository repo;
    private final CalculadoraRentabilidad calculadora;
    private final ControlAcceso acceso;
    private final ObjectMapper json;

    public AnalisisInversionService(AnalisisInversionRepository repo, CalculadoraRentabilidad calculadora,
                                    ControlAcceso acceso, ObjectMapper json) {
        this.repo = repo;
        this.calculadora = calculadora;
        this.acceso = acceso;
        this.json = json;
    }

    @Transactional(readOnly = true)
    public List<AnalisisInversionResponse> listar(UsuarioAutenticado actor) {
        return repo.findByIdUsuarioOrderByFechaActualizacionDesc(actor.id()).stream().map(this::respuesta).toList();
    }

    @Transactional
    public AnalisisInversionResponse crear(AnalisisInversionRequest req, UsuarioAutenticado actor) {
        if (repo.countByIdUsuario(actor.id()) >= MAXIMO_POR_USUARIO) {
            throw ApiException.conflicto("LIMITE_ANALISIS",
                    "Puedes guardar hasta " + MAXIMO_POR_USUARIO + " análisis; borra alguno antes");
        }
        AnalisisInversion a = new AnalisisInversion();
        a.setIdUsuario(actor.id());
        a.setFechaCreacion(LocalDateTime.now());
        aplicar(a, req, actor);
        return respuesta(repo.save(a));
    }

    @Transactional
    public AnalisisInversionResponse actualizar(Integer id, AnalisisInversionRequest req, UsuarioAutenticado actor) {
        AnalisisInversion a = propio(id, actor);
        aplicar(a, req, actor);
        return respuesta(a);
    }

    @Transactional
    public void borrar(Integer id, UsuarioAutenticado actor) {
        repo.delete(propio(id, actor));
    }

    /** Sin distinguir "no existe" de "es de otro" (IDOR): 404 en los dos casos. */
    private AnalisisInversion propio(Integer id, UsuarioAutenticado actor) {
        return repo.findByIdAndIdUsuario(id, actor.id()).orElseThrow(() -> ApiException.noEncontrado("Análisis"));
    }

    private void aplicar(AnalisisInversion a, AnalisisInversionRequest req, UsuarioAutenticado actor) {
        RentabilidadRequest e = req.entrada();
        validar(e);
        if (req.idPiso() != null) acceso.pisoVisible(req.idPiso(), actor);
        calculadora.responder(e); // comunidad desconocida u otros datos imposibles: 400 antes de guardar
        String datos;
        try {
            datos = json.writeValueAsString(e);
        } catch (JsonProcessingException ex) {
            throw ApiException.badRequest("DATOS_INVALIDOS", "No se pudieron guardar los datos");
        }
        if (datos.length() > 2000) throw ApiException.badRequest("DATOS_INVALIDOS", "Datos demasiado largos");
        a.setNombre(req.nombre().strip());
        a.setIdPiso(req.idPiso());
        a.setDatos(datos);
        a.setFechaActualizacion(LocalDateTime.now());
    }

    static void validar(RentabilidadRequest e) {
        if (e.comunidad().length() > 60) throw ApiException.badRequest("DATOS_INVALIDOS", "Comunidad no válida");
        boolean fueraDeRango = Stream.of(e.precioCompra(), e.gastosNotariaRegistro(), e.gastosHipoteca(), e.reforma(),
                        e.comisionCompra(), e.mobiliario(), e.ibiMensual(), e.segurosMensual(), e.comunidadMensual(),
                        e.mantenimientoMensual(), e.vacioMensual(), e.alquilerMensual(), e.revalorizacionAnualPct())
                .anyMatch(v -> v != null && (!Double.isFinite(v) || v > IMPORTE_MAXIMO));
        if (fueraDeRango) throw ApiException.badRequest("DATOS_INVALIDOS", "Algún importe está fuera de rango");
    }

    private AnalisisInversionResponse respuesta(AnalisisInversion a) {
        RentabilidadRequest entrada;
        try {
            entrada = json.readValue(a.getDatos(), RentabilidadRequest.class);
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException("Análisis " + a.getId() + " con datos ilegibles", ex);
        }
        RentabilidadResponse resultado;
        try {
            resultado = calculadora.responder(entrada);
        } catch (ApiException ex) {
            resultado = null; // p. ej., una comunidad que ya no está en la tabla de ITP
        }
        return new AnalisisInversionResponse(a.getId(), a.getNombre(), a.getIdPiso(),
                Textos.conZona(a.getFechaActualizacion()), entrada, resultado);
    }
}
