package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.ContratoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;

@Tag(name = "Contratos")
@RestController
@RequestMapping("/api/contratos")
public class ContratoController {

    private final ContratoService contratos;

    public ContratoController(ContratoService contratos) {
        this.contratos = contratos;
    }

    @Operation(summary = "Contrato de arrendamiento en PDF",
            description = "Para el ADMIN, el propietario del piso o el inquilino del contrato. No se guarda en disco.")
    @GetMapping(value = "/{id}/pdf", produces = MediaType.APPLICATION_PDF_VALUE)
    public ResponseEntity<byte[]> pdf(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        ContratoService.Pdf pdf = contratos.pdf(id, actor);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(pdf.nombreArchivo(), StandardCharsets.UTF_8).build().toString())
                .body(pdf.contenido());
    }
}
