package com.gestionap.api.web;

import org.springframework.web.bind.annotation.DeleteMapping;

import com.gestionap.api.service.CuentaService;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.GestionUsuariosService;
import com.gestionap.api.service.UsuarioService;
import com.gestionap.api.web.dto.ActualizarPerfilRequest;
import com.gestionap.api.web.dto.UsuarioResponse;
import com.gestionap.api.web.dto.UsuarioDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Usuario actual")
@RestController
@RequestMapping("/api/me")
public class MeController {

    private final UsuarioService usuarios;
    private final GestionUsuariosService gestion;
    private final CuentaService cuenta;

    public MeController(UsuarioService usuarios, GestionUsuariosService gestion, CuentaService cuenta) {
        this.usuarios = usuarios;
        this.gestion = gestion;
        this.cuenta = cuenta;
    }

    @Operation(summary = "Elimina la cuenta propia (pide la contraseña): anonimiza los datos personales y conserva contratos y pagos")
    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void eliminarCuenta(@Valid @RequestBody UsuarioDtos.EliminarCuentaRequest req,
                               @AuthenticationPrincipal UsuarioAutenticado actor) {
        cuenta.eliminar(req, actor);
    }

    @Operation(summary = "Datos del usuario autenticado")
    @GetMapping
    public UsuarioResponse me(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return usuarios.actual(actor);
    }

    @Operation(summary = "Cambia la contraseña comprobando la actual")
    @PutMapping("/password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cambiarPassword(@Valid @RequestBody UsuarioDtos.CambioPasswordRequest req,
                                @AuthenticationPrincipal UsuarioAutenticado actor) {
        gestion.cambiarPassword(req, actor);
    }

    @Operation(summary = "Actualiza nombre, email, DNI o IBAN (solo los campos enviados)")
    @PatchMapping
    public UsuarioResponse actualizar(@Valid @RequestBody ActualizarPerfilRequest req,
                                      @AuthenticationPrincipal UsuarioAutenticado actor) {
        return usuarios.actualizar(req, actor);
    }
}
