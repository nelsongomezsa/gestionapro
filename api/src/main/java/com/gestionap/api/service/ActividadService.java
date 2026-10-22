package com.gestionap.api.service;

import com.gestionap.api.domain.Actividad;
import com.gestionap.api.repository.ActividadRepository;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

/** Escribe en la misma tabla de actividad que el escritorio (ActividadDAO). */
@Service
public class ActividadService {

    private static final int MAX_DESCRIPCION = 255;

    private final ActividadRepository repo;

    public ActividadService(ActividadRepository repo) {
        this.repo = repo;
    }

    public void registrar(Integer idUsuario, String accion, String descripcion) {
        Actividad a = new Actividad();
        a.setIdUsuario(idUsuario);
        a.setAccion(accion);
        a.setDescripcion(descripcion != null && descripcion.length() > MAX_DESCRIPCION
                ? descripcion.substring(0, MAX_DESCRIPCION) : descripcion);
        a.setFecha(LocalDateTime.now());
        repo.save(a);
    }
}
