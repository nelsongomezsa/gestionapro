package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.InvitacionService;
import com.gestionap.api.web.dto.InvitacionResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Inquilinos")
@RestController
@RequestMapping("/api/inquilinos")
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class InquilinoController {

    private final InvitacionService invitaciones;

    public InquilinoController(InvitacionService invitaciones) {
        this.invitaciones = invitaciones;
    }

    @Operation(summary = "Genera un código de invitación (un solo uso, 7 días) para que el inquilino cree su cuenta",
            description = "Solo para inquilinos con contrato en un piso del propietario. "
                    + "Invalida las invitaciones pendientes anteriores. Si hay email configurado, también se le envía.")
    @PostMapping("/{id}/invitaciones")
    @ResponseStatus(HttpStatus.CREATED)
    public InvitacionResponse invitar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return invitaciones.generar(id, actor);
    }
}
