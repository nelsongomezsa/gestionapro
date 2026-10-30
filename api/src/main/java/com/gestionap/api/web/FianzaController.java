package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.FianzaService;
import com.gestionap.api.web.dto.DevolucionFianzaRequest;
import com.gestionap.api.web.dto.FianzaRequest;
import com.gestionap.api.web.dto.FianzaResponse;
import com.gestionap.api.web.dto.ResumenFianzasResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Fianzas", description = "Un PROPIETARIO gestiona las de sus contratos; un INQUILINO solo ve la suya")
@RestController
public class FianzaController {

    private final FianzaService fianzas;

    public FianzaController(FianzaService fianzas) {
        this.fianzas = fianzas;
    }

    @Operation(summary = "Fianza del contrato (404 si no tiene)")
    @GetMapping("/api/contratos/{id}/fianza")
    public FianzaResponse obtener(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return fianzas.obtener(id, actor);
    }

    @Operation(summary = "Crea o actualiza la fianza: importe, cobro y depósito")
    @PutMapping("/api/contratos/{id}/fianza")
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public FianzaResponse guardar(@PathVariable Integer id, @Valid @RequestBody FianzaRequest req,
                                 @AuthenticationPrincipal UsuarioAutenticado actor) {
        return fianzas.guardar(id, req, actor);
    }

    @Operation(summary = "Registra la devolución; si es parcial, el motivo es obligatorio")
    @PostMapping("/api/contratos/{id}/fianza/devolucion")
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public FianzaResponse devolver(@PathVariable Integer id, @Valid @RequestBody DevolucionFianzaRequest req,
                                  @AuthenticationPrincipal UsuarioAutenticado actor) {
        return fianzas.devolver(id, req, actor);
    }

    @Operation(summary = "Fianzas visibles y el total que aún hay que devolver")
    @GetMapping("/api/fianzas")
    public ResumenFianzasResponse listar(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return fianzas.listar(actor);
    }
}
