package com.gestionap.api.service;

import com.gestionap.api.domain.Inquilino;
import com.gestionap.api.domain.Rol;
import com.gestionap.api.domain.Usuario;
import com.gestionap.api.repository.InquilinoRepository;
import com.gestionap.api.repository.UsuarioRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.UsuarioResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UsuarioService {

    private final UsuarioRepository usuarios;
    private final InquilinoRepository inquilinos;

    public UsuarioService(UsuarioRepository usuarios, InquilinoRepository inquilinos) {
        this.usuarios = usuarios;
        this.inquilinos = inquilinos;
    }

    @Transactional(readOnly = true)
    public UsuarioResponse actual(UsuarioAutenticado actor) {
        return aRespuesta(usuarios.findById(actor.id()).orElseThrow(() -> ApiException.noEncontrado("Usuario")));
    }

    @Transactional(readOnly = true)
    public UsuarioResponse aRespuesta(Usuario u) {
        Integer idInquilino = u.getRol() == Rol.INQUILINO
                ? inquilinos.findByUsuarioId(u.getId()).map(Inquilino::getId).orElse(null)
                : null;
        return new UsuarioResponse(u.getId(), u.getNombre(), u.getEmail(), u.getRol(), idInquilino);
    }
}
