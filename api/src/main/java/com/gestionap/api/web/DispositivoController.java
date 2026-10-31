package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.PushService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Dispositivos", description = "Tokens de APNs para notificaciones push")
@RestController
@RequestMapping("/api/dispositivos")
public class DispositivoController {

    public record Registro(@NotBlank String token) {}

    private final PushService push;

    public DispositivoController(PushService push) {
        this.push = push;
    }

    @Operation(summary = "Registra el token de APNs de este iPhone para el usuario")
    @PostMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void registrar(@RequestBody Registro r, @AuthenticationPrincipal UsuarioAutenticado actor) {
        push.registrar(actor.id(), r.token());
    }

    @Operation(summary = "Lo quita al cerrar sesión")
    @DeleteMapping("/{token}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void borrar(@PathVariable String token, @AuthenticationPrincipal UsuarioAutenticado actor) {
        push.borrar(actor.id(), token);
    }
}
