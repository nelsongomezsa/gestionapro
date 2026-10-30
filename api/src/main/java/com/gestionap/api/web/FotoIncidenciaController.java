package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.FotoIncidenciaService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@Tag(name = "Fotos de incidencias", description = "Las sube el inquilino que la comunicó o quien gestiona el piso")
@RestController
@RequestMapping("/api/incidencias")
public class FotoIncidenciaController {

    private final FotoIncidenciaService fotos;

    public FotoIncidenciaController(FotoIncidenciaService fotos) {
        this.fotos = fotos;
    }

    @GetMapping("/{id}/fotos")
    public List<FotoIncidenciaService.Foto> listar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return fotos.listar(id, actor);
    }

    @Operation(summary = "Sube una foto (JPEG, PNG o HEIC, hasta 10 MB; máximo 10 por incidencia)")
    @PostMapping(value = "/{id}/fotos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public FotoIncidenciaService.Foto subir(@PathVariable Integer id, @RequestParam("archivo") MultipartFile archivo,
                                            @AuthenticationPrincipal UsuarioAutenticado actor) {
        return fotos.subir(id, archivo, actor);
    }

    @GetMapping("/fotos/{idFoto}")
    public ResponseEntity<byte[]> foto(@PathVariable Integer idFoto, @AuthenticationPrincipal UsuarioAutenticado actor) {
        var c = fotos.contenido(idFoto, actor);
        return ResponseEntity.ok().contentType(MediaType.parseMediaType(c.tipo())).body(c.datos());
    }

    @DeleteMapping("/fotos/{idFoto}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void borrar(@PathVariable Integer idFoto, @AuthenticationPrincipal UsuarioAutenticado actor) {
        fotos.borrar(idFoto, actor);
    }
}
