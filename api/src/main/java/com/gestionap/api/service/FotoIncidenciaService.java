package com.gestionap.api.service;

import com.gestionap.api.domain.FotoIncidencia;
import com.gestionap.api.domain.Incidencia;
import com.gestionap.api.domain.Rol;
import com.gestionap.api.repository.FotoIncidenciaRepository;
import com.gestionap.api.repository.IncidenciaRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Fotos de una incidencia: las puede subir quien la ve (el inquilino que la comunicó, el
 * propietario del piso o el admin). Borra una foto quien la subió o quien gestiona el piso.
 */
@Service
public class FotoIncidenciaService {

    static final int MAXIMO_FOTOS = 10;

    public record Foto(Integer id, LocalDateTime fecha, String tipo, boolean mia) {}

    private final FotoIncidenciaRepository fotos;
    private final IncidenciaService incidencias;
    private final ArchivoService archivos;
    private final ActividadService actividad;
    private final IncidenciaRepository incidenciasRepo;

    public FotoIncidenciaService(FotoIncidenciaRepository fotos, IncidenciaService incidencias, ArchivoService archivos,
                                 ActividadService actividad, IncidenciaRepository incidenciasRepo) {
        this.fotos = fotos;
        this.incidencias = incidencias;
        this.archivos = archivos;
        this.actividad = actividad;
        this.incidenciasRepo = incidenciasRepo;
    }

    @Transactional(readOnly = true)
    public List<Foto> listar(Integer idIncidencia, UsuarioAutenticado actor) {
        incidencias.cargarVisible(idIncidencia, actor);
        return fotos.findByIncidenciaIdOrderByFechaAscIdAsc(idIncidencia).stream().map(f -> aFoto(f, actor)).toList();
    }

    @Transactional
    public Foto subir(Integer idIncidencia, MultipartFile archivo, UsuarioAutenticado actor) {
        Incidencia i = incidencias.cargarVisible(idIncidencia, actor);
        // Dos subidas a la vez no pueden pasar del cupo: la incidencia queda bloqueada hasta el commit.
        incidenciasRepo.bloquear(idIncidencia);
        if (fotos.countByIncidenciaId(idIncidencia) >= MAXIMO_FOTOS) {
            throw ApiException.conflicto("DEMASIADAS_FOTOS", "Una incidencia admite " + MAXIMO_FOTOS + " fotos");
        }
        var guardado = archivos.guardar("incidencias", archivo);
        if (guardado.tipo().equals("application/pdf")) {
            archivos.borrar(guardado.ruta());
            throw ApiException.badRequest("TIPO_NO_ADMITIDO", "Solo fotos (JPEG, PNG o HEIC)");
        }
        FotoIncidencia f = new FotoIncidencia();
        f.setIncidencia(i);
        f.setRuta(guardado.ruta());
        f.setTipo(guardado.tipo());
        f.setIdUsuario(actor.id());
        f.setFecha(LocalDateTime.now());
        fotos.save(f);
        actividad.registrar(actor.id(), "FOTO_INCIDENCIA", "Incidencia #" + idIncidencia);
        return aFoto(f, actor);
    }

    @Transactional(readOnly = true)
    public ArchivoService.Contenido contenido(Integer idFoto, UsuarioAutenticado actor) {
        FotoIncidencia f = cargar(idFoto, actor);
        return archivos.leer(f.getRuta(), f.getTipo());
    }

    @Transactional
    public void borrar(Integer idFoto, UsuarioAutenticado actor) {
        FotoIncidencia f = cargar(idFoto, actor);
        if (actor.rol() == Rol.INQUILINO && !actor.id().equals(f.getIdUsuario())) {
            throw ApiException.conflicto("FOTO_AJENA", "Solo puedes borrar las fotos que has subido tú");
        }
        fotos.delete(f);
        archivos.borrar(f.getRuta());
    }

    private FotoIncidencia cargar(Integer idFoto, UsuarioAutenticado actor) {
        FotoIncidencia f = fotos.findById(idFoto).orElseThrow(() -> ApiException.noEncontrado("Foto"));
        incidencias.cargarVisible(f.getIncidencia().getId(), actor);
        return f;
    }

    private static Foto aFoto(FotoIncidencia f, UsuarioAutenticado actor) {
        return new Foto(f.getId(), f.getFecha(), f.getTipo(), actor.id().equals(f.getIdUsuario()));
    }
}
