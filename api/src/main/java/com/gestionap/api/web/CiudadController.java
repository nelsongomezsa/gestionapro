package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.CiudadService;
import com.gestionap.api.web.dto.CiudadResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Ciudades", description = "Ciudades en las que se dan de alta los pisos")
@RestController
@RequestMapping("/api/ciudades")
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class CiudadController {

    private final CiudadService ciudades;

    public CiudadController(CiudadService ciudades) {
        this.ciudades = ciudades;
    }

    public record CiudadRequest(
            @NotBlank @Size(min = 2, max = 100)
            @Pattern(regexp = "\\s*[\\p{L}][\\p{L} .'-]*", message = "solo letras, espacios, puntos, guiones y apóstrofos")
            String nombre) {}

    @Operation(summary = "Ciudades disponibles, por nombre")
    @GetMapping
    public List<CiudadResponse> listar() {
        return ciudades.listar();
    }

    @Operation(summary = "Da de alta una ciudad (201) o devuelve la que ya existe con ese nombre (200)")
    @PostMapping
    public ResponseEntity<CiudadResponse> crear(@Valid @RequestBody CiudadRequest req,
                                                @AuthenticationPrincipal UsuarioAutenticado actor) {
        var alta = ciudades.crear(req.nombre(), actor);
        return ResponseEntity.status(alta.nueva() ? HttpStatus.CREATED : HttpStatus.OK).body(alta.ciudad());
    }
}
