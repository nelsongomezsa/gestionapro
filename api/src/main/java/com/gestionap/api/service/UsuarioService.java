package com.gestionap.api.service;

import com.gestionap.api.domain.Inquilino;
import com.gestionap.api.domain.Rol;
import com.gestionap.api.domain.Usuario;
import com.gestionap.api.repository.InquilinoRepository;
import com.gestionap.api.repository.UsuarioRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.ActualizarPerfilRequest;
import com.gestionap.api.web.dto.UsuarioResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;

@Service
public class UsuarioService {

    private final UsuarioRepository usuarios;
    private final InquilinoRepository inquilinos;
    private final ActividadService actividad;

    public UsuarioService(UsuarioRepository usuarios, InquilinoRepository inquilinos, ActividadService actividad) {
        this.usuarios = usuarios;
        this.inquilinos = inquilinos;
        this.actividad = actividad;
    }

    @Transactional(readOnly = true)
    public UsuarioResponse actual(UsuarioAutenticado actor) {
        return aRespuesta(cargar(actor));
    }

    /** PATCH /api/me: nombre, email, DNI e IBAN (para el QR de pago). */
    @Transactional
    public UsuarioResponse actualizar(ActualizarPerfilRequest req, UsuarioAutenticado actor) {
        Usuario u = cargar(actor);
        if (req.nombre() != null) {
            if (req.nombre().isBlank()) throw ApiException.badRequest("NOMBRE_VACIO", "El nombre no puede estar vacío");
            u.setNombre(req.nombre().trim());
        }
        if (req.email() != null) {
            String email = req.email().trim().toLowerCase(Locale.ROOT);
            if (!email.equals(u.getEmail()) && usuarios.existsByEmail(email)) {
                throw ApiException.conflicto("EMAIL_EN_USO", "Ya existe una cuenta con ese email");
            }
            u.setEmail(email);
        }
        if (req.dni() != null) {
            u.setDni(req.dni().isBlank() ? null : req.dni().trim().toUpperCase(Locale.ROOT));
        }
        if (req.iban() != null) {
            String iban = Textos.normalizarIban(req.iban());
            if (!iban.isEmpty() && !Textos.ibanValido(iban)) {
                throw ApiException.badRequest("IBAN_NO_VALIDO", "El IBAN no es válido; revisa los dígitos");
            }
            u.setIban(iban.isEmpty() ? null : iban);
        }
        actividad.registrar(u.getId(), "EDITAR_PERFIL", "Datos de la cuenta actualizados desde la app");
        return aRespuesta(u);
    }

    @Transactional(readOnly = true)
    public UsuarioResponse aRespuesta(Usuario u) {
        Integer idInquilino = u.getRol() == Rol.INQUILINO
                ? inquilinos.findByUsuarioId(u.getId()).map(Inquilino::getId).orElse(null)
                : null;
        return new UsuarioResponse(u.getId(), u.getNombre(), u.getEmail(), u.getRol(), idInquilino, u.getDni(),
                u.getIban() == null ? null : Textos.ibanLegible(u.getIban()));
    }

    private Usuario cargar(UsuarioAutenticado actor) {
        return usuarios.findById(actor.id()).orElseThrow(() -> ApiException.noEncontrado("Usuario"));
    }
}
