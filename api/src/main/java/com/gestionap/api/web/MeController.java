package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.UsuarioService;
import com.gestionap.api.web.dto.UsuarioResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Usuario actual")
@RestController
public class MeController {

    private final UsuarioService usuarios;

    public MeController(UsuarioService usuarios) {
        this.usuarios = usuarios;
    }

    @Operation(summary = "Datos del usuario autenticado")
    @GetMapping("/api/me")
    public UsuarioResponse me(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return usuarios.actual(actor);
    }
}
