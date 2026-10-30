package com.gestionap.api.web;

import com.gestionap.api.domain.EstadoHabitacion;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.HabitacionService;
import com.gestionap.api.web.dto.CambioEstadoHabitacionRequest;
import com.gestionap.api.web.dto.HabitacionRequest;
import com.gestionap.api.web.dto.HabitacionResponse;
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

@Tag(name = "Habitaciones", description = "Un PROPIETARIO solo ve las de sus pisos; un ADMIN, todas")
@RestController
@RequestMapping("/api/habitaciones")
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class HabitacionController {

    private final HabitacionService habitaciones;

    public HabitacionController(HabitacionService habitaciones) {
        this.habitaciones = habitaciones;
    }

    @Operation(summary = "Lista con inquilino actual y días alquilada; filtros opcionales por piso, estado y texto")
    @GetMapping
    public List<HabitacionResponse> listar(@RequestParam(required = false) Integer piso,
                                           @RequestParam(required = false) EstadoHabitacion estado,
                                           @RequestParam(required = false) String q,
                                           @AuthenticationPrincipal UsuarioAutenticado actor) {
        return habitaciones.listar(piso, estado, q, actor);
    }

    @GetMapping("/{id}")
    public HabitacionResponse obtener(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return habitaciones.obtener(id, actor);
    }

    @Operation(summary = "Crea una habitación en un piso propio (409 si el número ya existe en ese piso)")
    @PostMapping
    public ResponseEntity<HabitacionResponse> crear(@Valid @RequestBody HabitacionRequest req,
                                                    @AuthenticationPrincipal UsuarioAutenticado actor) {
        HabitacionResponse h = habitaciones.crear(req, actor);
        var uri = ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}").buildAndExpand(h.id()).toUri();
        return ResponseEntity.created(uri).body(h);
    }

    @PutMapping("/{id}")
    public HabitacionResponse actualizar(@PathVariable Integer id, @Valid @RequestBody HabitacionRequest req,
                                         @AuthenticationPrincipal UsuarioAutenticado actor) {
        return habitaciones.actualizar(id, req, actor);
    }

    @Operation(summary = "Cambia el estado (409 si deja de estar alquilada con un contrato activo)")
    @PatchMapping("/{id}/estado")
    public HabitacionResponse cambiarEstado(@PathVariable Integer id, @Valid @RequestBody CambioEstadoHabitacionRequest req,
                                            @AuthenticationPrincipal UsuarioAutenticado actor) {
        return habitaciones.cambiarEstado(id, req.estado(), actor);
    }

    @Operation(summary = "Borra una habitación sin contratos ni incidencias (409 si los tiene)")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void borrar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        habitaciones.borrar(id, actor);
    }
}
