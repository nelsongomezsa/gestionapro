package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.AnalisisInversionService;
import com.gestionap.api.web.dto.AnalisisInversionDtos.AnalisisInversionRequest;
import com.gestionap.api.web.dto.AnalisisInversionDtos.AnalisisInversionResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Análisis de inversión", description = "Simulaciones de la calculadora guardadas por cada usuario")
@RestController
@RequestMapping("/api/analisis-inversion")
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class AnalisisInversionController {

    private final AnalisisInversionService servicio;

    public AnalisisInversionController(AnalisisInversionService servicio) {
        this.servicio = servicio;
    }

    @Operation(summary = "Mis análisis guardados, del más reciente al más antiguo, con su resultado")
    @GetMapping
    public List<AnalisisInversionResponse> listar(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return servicio.listar(actor);
    }

    @Operation(summary = "Guarda un análisis con nombre (máximo 50 por usuario)")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AnalisisInversionResponse crear(@Valid @RequestBody AnalisisInversionRequest req,
                                           @AuthenticationPrincipal UsuarioAutenticado actor) {
        return servicio.crear(req, actor);
    }

    @Operation(summary = "Cambia el nombre o los datos de un análisis propio")
    @PutMapping("/{id}")
    public AnalisisInversionResponse actualizar(@PathVariable Integer id, @Valid @RequestBody AnalisisInversionRequest req,
                                                @AuthenticationPrincipal UsuarioAutenticado actor) {
        return servicio.actualizar(id, req, actor);
    }

    @Operation(summary = "Borra un análisis propio")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void borrar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        servicio.borrar(id, actor);
    }
}
