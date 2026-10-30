package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.InquilinoService;
import com.gestionap.api.service.InvitacionService;
import com.gestionap.api.web.dto.InquilinoRequest;
import com.gestionap.api.web.dto.InquilinoResponse;
import com.gestionap.api.web.dto.InvitacionResponse;
import com.gestionap.api.web.dto.QrPagoResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import java.util.List;

@Tag(name = "Inquilinos", description = "Un PROPIETARIO ve los que dio de alta y los que tienen contrato en sus pisos")
@RestController
@RequestMapping("/api/inquilinos")
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class InquilinoController {

    private final InquilinoService inquilinos;
    private final InvitacionService invitaciones;

    public InquilinoController(InquilinoService inquilinos, InvitacionService invitaciones) {
        this.inquilinos = inquilinos;
        this.invitaciones = invitaciones;
    }

    @Operation(summary = "Lista con contrato activo; búsqueda por nombre, DNI, teléfono o email")
    @GetMapping
    public List<InquilinoResponse> listar(@RequestParam(required = false) String q,
                                          @AuthenticationPrincipal UsuarioAutenticado actor) {
        return inquilinos.listar(q, actor);
    }

    @Operation(summary = "Ficha: datos, contratos y últimos 24 pagos")
    @GetMapping("/{id}")
    public InquilinoResponse obtener(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return inquilinos.obtener(id, actor);
    }

    @Operation(summary = "Da de alta un inquilino (409 si el DNI ya existe)")
    @PostMapping
    public ResponseEntity<InquilinoResponse> crear(@Valid @RequestBody InquilinoRequest req,
                                                   @AuthenticationPrincipal UsuarioAutenticado actor) {
        InquilinoResponse i = inquilinos.crear(req, actor);
        var uri = ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}").buildAndExpand(i.id()).toUri();
        return ResponseEntity.created(uri).body(i);
    }

    @PutMapping("/{id}")
    public InquilinoResponse actualizar(@PathVariable Integer id, @Valid @RequestBody InquilinoRequest req,
                                        @AuthenticationPrincipal UsuarioAutenticado actor) {
        return inquilinos.actualizar(id, req, actor);
    }

    @Operation(summary = "Borra un inquilino sin contratos ni incidencias (409 si los tiene)")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void borrar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        inquilinos.borrar(id, actor);
    }

    @Operation(summary = "Datos del QR de pago SEPA del alquiler del mes (409 sin contrato activo o sin IBAN)")
    @GetMapping("/{id}/qr-pago")
    public QrPagoResponse qrPago(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return inquilinos.qrPago(id, actor);
    }

    @Operation(summary = "Genera un código de invitación (un solo uso, 7 días) para que el inquilino cree su cuenta",
            description = "Solo para inquilinos visibles. Invalida las invitaciones pendientes anteriores. "
                    + "Si hay email configurado, también se le envía.")
    @PostMapping("/{id}/invitaciones")
    @ResponseStatus(HttpStatus.CREATED)
    public InvitacionResponse invitar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return invitaciones.generar(id, actor);
    }
}
