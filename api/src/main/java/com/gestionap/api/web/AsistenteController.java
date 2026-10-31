package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.AsistenteService;
import com.gestionap.api.web.dto.AsistenteDtos.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@Tag(name = "Asistente", description = "Asistente con IA (API de Claude desde el servidor). Las acciones se proponen y la app las confirma")
@RestController
@RequestMapping("/api/asistente")
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class AsistenteController {

    private final AsistenteService asistente;

    public AsistenteController(AsistenteService asistente) {
        this.asistente = asistente;
    }

    @Operation(summary = "Si está activo (hay clave en el servidor) y cuántas consultas quedan hoy")
    @GetMapping("/estado")
    public Estado estado(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return asistente.estado(actor);
    }

    @Operation(summary = "Pregunta al asistente. Devuelve la respuesta y las acciones propuestas (sin ejecutar)")
    @PostMapping("/conversar")
    public Contestacion conversar(@Valid @RequestBody Pregunta pregunta, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return asistente.conversar(pregunta, actor);
    }

    @Operation(summary = "Propone categoría y urgencia de una incidencia a partir de su descripción")
    @PostMapping("/clasificar-incidencia")
    public ClasificacionIncidencia clasificar(@Valid @RequestBody DescripcionIncidencia req,
                                              @AuthenticationPrincipal UsuarioAutenticado actor) {
        return asistente.clasificar(req.descripcion(), actor);
    }

    @Operation(summary = "Lee la foto de una factura (JPEG o PNG) y propone el gasto para revisarlo")
    @PostMapping(value = "/leer-factura", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public PropuestaGasto leerFactura(@RequestParam("archivo") MultipartFile foto, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return asistente.leerFactura(foto, actor);
    }
}
