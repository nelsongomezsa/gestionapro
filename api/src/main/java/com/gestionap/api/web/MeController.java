package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.UsuarioService;
import com.gestionap.api.web.dto.ActualizarPerfilRequest;
import com.gestionap.api.web.dto.UsuarioResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Usuario actual")
@RestController
@RequestMapping("/api/me")
public class MeController {

    private final UsuarioService usuarios;

    public MeController(UsuarioService usuarios) {
        this.usuarios = usuarios;
    }

    @Operation(summary = "Datos del usuario autenticado")
    @GetMapping
    public UsuarioResponse me(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return usuarios.actual(actor);
    }

    @Operation(summary = "Actualiza nombre, email, DNI o IBAN (solo los campos enviados)")
    @PatchMapping
    public UsuarioResponse actualizar(@Valid @RequestBody ActualizarPerfilRequest req,
                                      @AuthenticationPrincipal UsuarioAutenticado actor) {
        return usuarios.actualizar(req, actor);
    }
}
