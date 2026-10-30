package com.gestionap.api.service;

import com.gestionap.api.domain.Piso;
import com.gestionap.api.repository.PisoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import org.springframework.stereotype.Component;

/**
 * Regla de acceso común: el ADMIN ve todo, un PROPIETARIO solo lo de sus pisos.
 * Lo ajeno responde 404 (no 403) para no revelar qué ids existen.
 */
@Component
public class ControlAcceso {

    private final PisoRepository pisos;

    public ControlAcceso(PisoRepository pisos) {
        this.pisos = pisos;
    }

    /** Id de propietario por el que filtrar las consultas; null para el admin (sin filtro). */
    public Integer filtroPropietario(UsuarioAutenticado actor) {
        return actor.esAdmin() ? null : actor.id();
    }

    public boolean puedeVerPiso(Piso piso, UsuarioAutenticado actor) {
        return actor.esAdmin() || piso.getPropietario().getId().equals(actor.id());
    }

    public Piso pisoVisible(Integer idPiso, UsuarioAutenticado actor) {
        Piso p = pisos.findWithDetallesById(idPiso).orElseThrow(() -> ApiException.noEncontrado("Piso"));
        if (!puedeVerPiso(p, actor)) throw ApiException.noEncontrado("Piso");
        return p;
    }
}
