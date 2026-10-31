package com.gestionap.api.web;

import com.gestionap.api.security.LimiteIntentos;
import jakarta.servlet.http.HttpServletRequest;
import java.util.function.Supplier;

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
    private final LimiteIntentos limites;

    public AuthController(AuthService auth, UsuarioService usuarios, LimiteIntentos limites) {
        this.auth = auth;
        this.usuarios = usuarios;
        this.limites = limites;
    }

    @Operation(summary = "Inicia sesión y devuelve un JWT")
    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest req, HttpServletRequest http) {
        return limitado(http, req.email(), () -> auth.login(req.email(), req.password()));
    }

    @Operation(summary = "Crea la cuenta de un inquilino con un código de invitación")
    @PostMapping("/register-inquilino")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenResponse registrarInquilino(@Valid @RequestBody RegistroInquilinoRequest req, HttpServletRequest http) {
        return limitado(http, req.email(), () -> auth.registrarInquilino(req));
    }

    /** 429 con Retry-After si la IP o el email han agotado sus intentos; los fallos cuentan para el email. */
    private TokenResponse limitado(HttpServletRequest http, String email, Supplier<AuthService.Sesion> accion) {
        limites.comprobar(http.getRemoteAddr(), email);
        try {
            AuthService.Sesion s = accion.get();
            limites.acierto(email);
            return respuesta(s);
        } catch (ApiException e) {
            limites.fallo(email);
            throw e;
        }
    }

    private TokenResponse respuesta(AuthService.Sesion s) {
        return TokenResponse.bearer(s.token().valor(), s.token().expira(), usuarios.aRespuesta(s.usuario()));
    }
}
