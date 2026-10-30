package com.gestionap.api.service;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.Inquilino;
import com.gestionap.api.domain.Piso;
import com.gestionap.api.domain.Rol;
import com.gestionap.api.repository.InquilinoRepository;
import com.gestionap.api.repository.PisoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import org.springframework.stereotype.Component;

/**
 * Regla de acceso común: el ADMIN ve todo, un PROPIETARIO solo lo de sus pisos y un
 * INQUILINO solo lo suyo. Lo ajeno responde 404 (no 403) para no revelar qué ids existen.
 */
@Component
public class ControlAcceso {

    /** Id que nunca existe: un inquilino sin ficha enlazada no ve nada. */
    private static final int NINGUNO = -1;

    private final PisoRepository pisos;
    private final InquilinoRepository inquilinos;

    public ControlAcceso(PisoRepository pisos, InquilinoRepository inquilinos) {
        this.pisos = pisos;
        this.inquilinos = inquilinos;
    }

    /** Filtros para las consultas: (null, null) para el admin. */
    public record Alcance(Integer idPropietario, Integer idInquilino) {}

    public Alcance alcance(UsuarioAutenticado actor) {
        return switch (actor.rol()) {
            case ADMIN -> new Alcance(null, null);
            case PROPIETARIO -> new Alcance(actor.id(), null);
            case INQUILINO -> new Alcance(null, inquilinos.findByUsuarioId(actor.id()).map(Inquilino::getId).orElse(NINGUNO));
        };
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

    /** El admin, el propietario del piso o el inquilino del contrato. */
    public boolean puedeVerContrato(Contrato c, UsuarioAutenticado actor) {
        if (actor.rol() == Rol.INQUILINO) {
            return c.getInquilino().getUsuario() != null && c.getInquilino().getUsuario().getId().equals(actor.id());
        }
        return puedeVerPiso(c.getHabitacion().getPiso(), actor);
    }
}
