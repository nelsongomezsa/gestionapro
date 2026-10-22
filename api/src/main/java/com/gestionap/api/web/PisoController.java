package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.PisoService;
import com.gestionap.api.web.dto.PisoRequest;
import com.gestionap.api.web.dto.PisoResponse;
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

@Tag(name = "Pisos", description = "Un PROPIETARIO solo ve los suyos; un ADMIN ve todos")
@RestController
@RequestMapping("/api/pisos")
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class PisoController {

    private final PisoService pisos;

    public PisoController(PisoService pisos) {
        this.pisos = pisos;
    }

    @Operation(summary = "Lista los pisos con ocupación, ingresos y métricas de rentabilidad")
    @GetMapping
    public List<PisoResponse> listar(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return pisos.listar(actor);
    }

    @GetMapping("/{id}")
    public PisoResponse obtener(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return pisos.obtener(id, actor);
    }

    @Operation(summary = "Crea un piso cuyo propietario es el usuario autenticado")
    @PostMapping
    public ResponseEntity<PisoResponse> crear(@Valid @RequestBody PisoRequest req,
                                              @AuthenticationPrincipal UsuarioAutenticado actor) {
        PisoResponse creado = pisos.crear(req, actor);
        var uri = ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}").buildAndExpand(creado.id()).toUri();
        return ResponseEntity.created(uri).body(creado);
    }

    @PutMapping("/{id}")
    public PisoResponse actualizar(@PathVariable Integer id, @Valid @RequestBody PisoRequest req,
                                   @AuthenticationPrincipal UsuarioAutenticado actor) {
        return pisos.actualizar(id, req, actor);
    }

    @Operation(summary = "Borra un piso sin habitaciones (409 si tiene)")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void borrar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        pisos.borrar(id, actor);
    }
}
