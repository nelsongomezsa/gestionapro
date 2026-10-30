package com.gestionap.api.web;

import com.gestionap.api.domain.EstadoIncidencia;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.IncidenciaService;
import com.gestionap.api.web.dto.IncidenciaDtos.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Incidencias", description = "Un PROPIETARIO gestiona las de sus pisos; un INQUILINO ve y comunica las suyas")
@RestController
@RequestMapping("/api/incidencias")
public class IncidenciaController {

    private final IncidenciaService incidencias;

    public IncidenciaController(IncidenciaService incidencias) {
        this.incidencias = incidencias;
    }

    @Operation(summary = "Lista, opcionalmente por estado y piso")
    @GetMapping
    public List<IncidenciaResponse> listar(@RequestParam(required = false) EstadoIncidencia estado,
                                           @RequestParam(required = false) Integer piso,
                                           @AuthenticationPrincipal UsuarioAutenticado actor) {
        return incidencias.listar(estado, piso, actor);
    }

    @GetMapping("/{id}")
    public IncidenciaResponse obtener(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return incidencias.obtener(id, actor);
    }

    @Operation(summary = "Nueva incidencia (un inquilino la crea en la habitación de su contrato activo)")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public IncidenciaResponse crear(@Valid @RequestBody IncidenciaRequest req, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return incidencias.crear(req, actor);
    }

    @Operation(summary = "Cambia el estado; sin estado, avanza un paso (pendiente → en proceso → resuelta)")
    @PatchMapping("/{id}/estado")
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public IncidenciaResponse cambiarEstado(@PathVariable Integer id, @RequestBody(required = false) CambioEstadoRequest req,
                                            @AuthenticationPrincipal UsuarioAutenticado actor) {
        return incidencias.cambiarEstado(id, req == null ? null : req.estado(), actor);
    }

    @Operation(summary = "Edita la descripción o el coste de reparación")
    @PatchMapping("/{id}")
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public IncidenciaResponse actualizar(@PathVariable Integer id, @Valid @RequestBody ActualizarIncidenciaRequest req,
                                         @AuthenticationPrincipal UsuarioAutenticado actor) {
        return incidencias.actualizar(id, req, actor);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public void borrar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        incidencias.borrar(id, actor);
    }
}
