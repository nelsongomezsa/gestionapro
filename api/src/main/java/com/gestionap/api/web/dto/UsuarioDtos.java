package com.gestionap.api.web.dto;

import com.gestionap.api.domain.Rol;
import com.gestionap.api.domain.Usuario;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;

public final class UsuarioDtos {

    private UsuarioDtos() {}

    public record CambioPasswordRequest(
            @NotBlank String actual,
            @NotBlank @Size(min = 8, max = 72, message = "debe tener entre 8 y 72 caracteres") String nueva) {}

    /** Fila de la gestión de usuarios (solo admin). */
    public record UsuarioAdmin(Integer id, String nombre, String email, Rol rol, boolean activo) {
        public static UsuarioAdmin de(Usuario u) {
            return new UsuarioAdmin(u.getId(), u.getNombre(), u.getEmail(), u.getRol(), u.isActivo());
        }
    }

    public record NuevoUsuarioRequest(
            @NotBlank @Size(max = 100) String nombre,
            @NotBlank @Email @Size(max = 100) String email,
            @NotBlank @Size(min = 8, max = 72, message = "debe tener entre 8 y 72 caracteres") String password,
            @Schema(description = "ADMIN o PROPIETARIO; los inquilinos se dan de alta con una invitación") @NotNull Rol rol) {}

    public record CambioActivoRequest(@NotNull Boolean activo) {}

    public record CambioRolRequest(@NotNull Rol rol) {}
}
