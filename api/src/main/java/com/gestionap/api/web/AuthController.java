package com.gestionap.api.web;

import com.gestionap.api.service.AuthService;
import com.gestionap.api.service.UsuarioService;
import com.gestionap.api.web.dto.LoginRequest;
import com.gestionap.api.web.dto.RegistroInquilinoRequest;
import com.gestionap.api.web.dto.TokenResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Autenticación")
@SecurityRequirements
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService auth;
    private final UsuarioService usuarios;

    public AuthController(AuthService auth, UsuarioService usuarios) {
        this.auth = auth;
        this.usuarios = usuarios;
    }

    @Operation(summary = "Inicia sesión y devuelve un JWT")
    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest req) {
        return respuesta(auth.login(req.email(), req.password()));
    }

    @Operation(summary = "Crea la cuenta de un inquilino con un código de invitación")
    @PostMapping("/register-inquilino")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenResponse registrarInquilino(@Valid @RequestBody RegistroInquilinoRequest req) {
        return respuesta(auth.registrarInquilino(req));
    }

    private TokenResponse respuesta(AuthService.Sesion s) {
        return TokenResponse.bearer(s.token().valor(), s.token().expira(), usuarios.aRespuesta(s.usuario()));
    }
}
