package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.GestionUsuariosService;
import com.gestionap.api.web.dto.UsuarioDtos.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Usuarios", description = "Solo ADMIN. Un inquilino no puede cambiar de rol")
@RestController
@RequestMapping("/api/usuarios")
@PreAuthorize("hasRole('ADMIN')")
public class UsuarioController {

    private final GestionUsuariosService usuarios;

    public UsuarioController(GestionUsuariosService usuarios) {
        this.usuarios = usuarios;
    }

    @GetMapping
    public List<UsuarioAdmin> listar() {
        return usuarios.listar();
    }

    @Operation(summary = "Nuevo usuario ADMIN o PROPIETARIO (los inquilinos van por invitación)")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UsuarioAdmin crear(@Valid @RequestBody NuevoUsuarioRequest req, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return usuarios.crear(req, actor);
    }

    @Operation(summary = "Activa o desactiva (no la propia cuenta)")
    @PatchMapping("/{id}/activo")
    public UsuarioAdmin activo(@PathVariable Integer id, @Valid @RequestBody CambioActivoRequest req,
                               @AuthenticationPrincipal UsuarioAutenticado actor) {
        return usuarios.cambiarActivo(id, req.activo(), actor);
    }

    @Operation(summary = "Cambia el rol (no el propio; un inquilino no puede cambiar de rol)")
    @PatchMapping("/{id}/rol")
    public UsuarioAdmin rol(@PathVariable Integer id, @Valid @RequestBody CambioRolRequest req,
                            @AuthenticationPrincipal UsuarioAutenticado actor) {
        return usuarios.cambiarRol(id, req.rol(), actor);
    }
}
