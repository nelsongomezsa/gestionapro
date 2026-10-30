package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.InventarioService;
import com.gestionap.api.web.dto.InventarioDtos.InventarioRequest;
import com.gestionap.api.web.dto.InventarioDtos.InventarioResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.util.List;

@Tag(name = "Inventarios", description = "Entrada y salida por habitación, con fotos y PDF; el inquilino ve los de sus contratos")
@RestController
@RequestMapping("/api")
public class InventarioController {

    private final InventarioService inventarios;

    public InventarioController(InventarioService inventarios) {
        this.inventarios = inventarios;
    }

    @GetMapping("/habitaciones/{id}/inventarios")
    public List<InventarioResponse> listar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return inventarios.listar(id, actor);
    }

    @Operation(summary = "Crea un inventario de entrada o salida con sus elementos")
    @PostMapping("/habitaciones/{id}/inventarios")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public InventarioResponse crear(@PathVariable Integer id, @Valid @RequestBody InventarioRequest req,
                                    @AuthenticationPrincipal UsuarioAutenticado actor) {
        return inventarios.crear(id, req, actor);
    }

    @GetMapping("/inventarios/{id}")
    public InventarioResponse obtener(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return inventarios.obtener(id, actor);
    }

    @DeleteMapping("/inventarios/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public void borrar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        inventarios.borrar(id, actor);
    }

    @Operation(summary = "Foto de un elemento (JPEG, PNG o HEIC, hasta 10 MB); sustituye a la anterior")
    @PostMapping(value = "/inventarios/elementos/{idElemento}/foto", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public InventarioResponse subirFoto(@PathVariable Integer idElemento, @RequestParam("archivo") MultipartFile archivo,
                                        @AuthenticationPrincipal UsuarioAutenticado actor) {
        return inventarios.subirFoto(idElemento, archivo, actor);
    }

    @GetMapping("/inventarios/elementos/{idElemento}/foto")
    public ResponseEntity<byte[]> foto(@PathVariable Integer idElemento, @AuthenticationPrincipal UsuarioAutenticado actor) {
        var c = inventarios.foto(idElemento, actor);
        return ResponseEntity.ok().contentType(MediaType.parseMediaType(c.tipo())).body(c.datos());
    }

    @Operation(summary = "Inventario en PDF, con fotos y espacio para las firmas")
    @GetMapping(value = "/inventarios/{id}/pdf", produces = MediaType.APPLICATION_PDF_VALUE)
    public ResponseEntity<byte[]> pdf(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        var pdf = inventarios.pdf(id, actor);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(pdf.nombreArchivo(), StandardCharsets.UTF_8).build().toString())
                .body(pdf.contenido());
    }
}
