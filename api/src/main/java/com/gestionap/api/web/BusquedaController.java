package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.BusquedaService;
import com.gestionap.api.web.dto.BusquedaResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Búsqueda global")
@RestController
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class BusquedaController {

    private final BusquedaService busqueda;

    public BusquedaController(BusquedaService busqueda) {
        this.busqueda = busqueda;
    }

    @Operation(summary = "Busca en pisos, inquilinos, contratos e incidencias (mínimo 2 caracteres; sin tildes)")
    @GetMapping("/api/buscar")
    public BusquedaResponse buscar(@RequestParam String q, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return busqueda.buscar(q, actor);
    }
}
