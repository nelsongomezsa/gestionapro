package com.gestionap.api.service;

import com.gestionap.api.domain.EstadoIncidencia;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.IncidenciaRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.BusquedaResponse;
import com.gestionap.api.web.dto.BusquedaResponse.Resultado;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.Normalizer;
import java.time.LocalDate;
import java.util.EnumSet;
import java.util.stream.Stream;

/** Busca en pisos, inquilinos, contratos e incidencias visibles para el usuario, sin tildes ni mayúsculas. */
@Service
public class BusquedaService {

    private static final int MAX = 10;

    private final PisoService pisos;
    private final InquilinoService inquilinos;
    private final ContratoRepository contratos;
    private final IncidenciaRepository incidencias;
    private final ControlAcceso acceso;

    public BusquedaService(PisoService pisos, InquilinoService inquilinos, ContratoRepository contratos,
                           IncidenciaRepository incidencias, ControlAcceso acceso) {
        this.pisos = pisos;
        this.inquilinos = inquilinos;
        this.contratos = contratos;
        this.incidencias = incidencias;
        this.acceso = acceso;
    }

    @Transactional(readOnly = true)
    public BusquedaResponse buscar(String texto, UsuarioAutenticado actor) {
        String q = normalizar(texto == null ? "" : texto.trim());
        if (q.length() < 2) throw ApiException.badRequest("BUSQUEDA_CORTA", "Escribe al menos 2 caracteres");
        Integer prop = acceso.filtroPropietario(actor);
        LocalDate hoy = LocalDate.now();

        var rPisos = pisos.listar(actor).stream()
                .filter(p -> coincide(q, p.direccion(), p.ciudad().nombre()))
                .limit(MAX).map(p -> new Resultado(p.id(), p.direccion(), p.ciudad().nombre())).toList();
        var rInquilinos = inquilinos.listar(null, actor).stream()
                .filter(i -> coincide(q, i.nombre() + " " + i.apellidos(), i.dni(), i.telefono(), i.email()))
                .limit(MAX).map(i -> new Resultado(i.id(), i.nombre() + " " + i.apellidos(),
                        i.contratoActivo() != null ? "Hab. " + i.contratoActivo().numeroHabitacion() + " · " + i.contratoActivo().piso().direccion()
                                : "Sin contrato activo")).toList();
        var rContratos = contratos.buscar(prop, null, null).stream()
                .filter(c -> coincide(q, c.getInquilino().getNombreCompleto(), c.getHabitacion().getPiso().getDireccion()))
                .limit(MAX).map(c -> new Resultado(c.getId(), c.getInquilino().getNombreCompleto(),
                        "Hab. " + c.getHabitacion().getNumero() + " · " + c.getHabitacion().getPiso().getDireccion()
                                + (c.estaActivoEn(hoy) ? "" : " · finalizado"))).toList();
        var rIncidencias = incidencias.buscar(prop, null, null, EnumSet.allOf(EstadoIncidencia.class)).stream()
                .filter(i -> coincide(q, i.getDescripcion(), i.getHabitacion().getPiso().getDireccion()))
                .limit(MAX).map(i -> new Resultado(i.getId(), i.getDescripcion(),
                        "Hab. " + i.getHabitacion().getNumero() + " · " + i.getEstado().name().replace('_', ' '))).toList();
        return new BusquedaResponse(rPisos, rInquilinos, rContratos, rIncidencias);
    }

    private static boolean coincide(String q, String... campos) {
        return Stream.of(campos).anyMatch(c -> c != null && normalizar(c).contains(q));
    }

    /** "García" y "garcia" coinciden. */
    static String normalizar(String s) {
        return Normalizer.normalize(s, Normalizer.Form.NFD).replaceAll("\\p{M}", "").toLowerCase(Textos.ES);
    }
}
