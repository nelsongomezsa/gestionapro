package com.gestionap.api.security;

import com.gestionap.api.domain.Rol;
import com.gestionap.api.domain.Usuario;

/** Principal de Spring Security: lo justo para autorizar sin volver a la BD. */
public record UsuarioAutenticado(Integer id, String email, String nombre, Rol rol) {

    public static UsuarioAutenticado de(Usuario u) {
        return new UsuarioAutenticado(u.getId(), u.getEmail(), u.getNombre(), u.getRol());
    }

    public boolean esAdmin() {
        return rol == Rol.ADMIN;
    }
}
