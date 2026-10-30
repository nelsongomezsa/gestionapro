package com.gestionap.api.service;

import com.gestionap.api.domain.Rol;
import com.gestionap.api.domain.Usuario;
import com.gestionap.api.repository.UsuarioRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.UsuarioDtos.*;
import org.springframework.data.domain.Sort;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Locale;

/**
 * Gestión de usuarios (UsuariosController del escritorio, solo admin) y cambio de contraseña.
 * Mismas restricciones que el parche del escritorio: un inquilino no puede cambiar de rol
 * (ascenderlo le daría acceso a todo) y no se crean inquilinos desde aquí (van por invitación).
 */
@Service
public class GestionUsuariosService {

    private static final int MAX_BYTES_PASSWORD = 72;

    private final UsuarioRepository usuarios;
    private final PasswordEncoder encoder;
    private final ActividadService actividad;

    public GestionUsuariosService(UsuarioRepository usuarios, PasswordEncoder encoder, ActividadService actividad) {
        this.usuarios = usuarios;
        this.encoder = encoder;
        this.actividad = actividad;
    }

    @Transactional
    public void cambiarPassword(CambioPasswordRequest req, UsuarioAutenticado actor) {
        Usuario u = usuarios.findById(actor.id()).orElseThrow(() -> ApiException.noEncontrado("Usuario"));
        if (!encoder.matches(req.actual(), u.getPasswordHash())) {
            throw ApiException.badRequest("PASSWORD_ACTUAL_INCORRECTA", "La contraseña actual no es correcta");
        }
        exigirLongitud(req.nueva());
        if (encoder.matches(req.nueva(), u.getPasswordHash())) {
            throw ApiException.badRequest("PASSWORD_IGUAL", "La nueva contraseña debe ser distinta de la actual");
        }
        u.setPasswordHash(encoder.encode(req.nueva()));
        actividad.registrar(u.getId(), "CAMBIAR_PASSWORD", "Contraseña cambiada desde la app");
    }

    @Transactional(readOnly = true)
    public List<UsuarioAdmin> listar() {
        return usuarios.findAll(Sort.by("nombre")).stream().map(UsuarioAdmin::de).toList();
    }

    @Transactional
    public UsuarioAdmin crear(NuevoUsuarioRequest req, UsuarioAutenticado actor) {
        if (req.rol() == Rol.INQUILINO) {
            throw ApiException.badRequest("ROL_NO_PERMITIDO", "Los inquilinos se dan de alta con una invitación desde su ficha");
        }
        exigirLongitud(req.password());
        String email = req.email().trim().toLowerCase(Locale.ROOT);
        if (usuarios.existsByEmail(email)) throw ApiException.conflicto("EMAIL_EN_USO", "Ya existe una cuenta con ese email");
        Usuario u = new Usuario();
        u.setNombre(req.nombre().trim());
        u.setEmail(email);
        u.setPasswordHash(encoder.encode(req.password()));
        u.setRol(req.rol());
        u.setActivo(true);
        usuarios.save(u);
        actividad.registrar(actor.id(), "CREAR_USUARIO", u.getNombre() + " (" + u.getRol() + ")");
        return UsuarioAdmin.de(u);
    }

    @Transactional
    public UsuarioAdmin cambiarActivo(Integer id, boolean activo, UsuarioAutenticado actor) {
        Usuario u = cargar(id);
        if (u.getId().equals(actor.id()) && !activo) {
            throw ApiException.conflicto("NO_PUEDES_DESACTIVARTE", "No puedes desactivar tu propia cuenta");
        }
        u.setActivo(activo);
        actividad.registrar(actor.id(), activo ? "ACTIVAR_USUARIO" : "DESACTIVAR_USUARIO", u.getNombre());
        return UsuarioAdmin.de(u);
    }

    @Transactional
    public UsuarioAdmin cambiarRol(Integer id, Rol rol, UsuarioAutenticado actor) {
        Usuario u = cargar(id);
        if (u.getRol() == Rol.INQUILINO) {
            throw ApiException.conflicto("INQUILINO_NO_CAMBIA_ROL",
                    "Las cuentas de inquilino no pueden cambiar de rol (le daría acceso a todos los datos)");
        }
        if (rol == Rol.INQUILINO) {
            throw ApiException.badRequest("ROL_NO_PERMITIDO", "Una cuenta no puede pasar a ser de inquilino");
        }
        if (u.getId().equals(actor.id())) {
            throw ApiException.conflicto("NO_PUEDES_CAMBIAR_TU_ROL", "No puedes cambiar tu propio rol");
        }
        u.setRol(rol);
        actividad.registrar(actor.id(), "CAMBIAR_ROL", u.getNombre() + " → " + rol);
        return UsuarioAdmin.de(u);
    }

    private Usuario cargar(Integer id) {
        return usuarios.findById(id).orElseThrow(() -> ApiException.noEncontrado("Usuario"));
    }

    private static void exigirLongitud(String password) {
        if (password.getBytes(StandardCharsets.UTF_8).length > MAX_BYTES_PASSWORD) {
            throw ApiException.badRequest("PASSWORD_DEMASIADO_LARGA", "La contraseña es demasiado larga");
        }
    }
}
