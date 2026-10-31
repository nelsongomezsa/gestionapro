package com.gestionap.api.web;

import com.gestionap.api.domain.FirmaContrato.Parte;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.FirmaService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;

@Tag(name = "Firma de contratos", description = "Firma electrónica simple en pantalla; preparada para un proveedor con validez reforzada")
@RestController
@RequestMapping("/api/contratos/{id}")
public class FirmaController {

    private final FirmaService firmas;

    public FirmaController(FirmaService firmas) {
        this.firmas = firmas;
    }

    @Operation(summary = "Firmas del contrato y si siguen valiendo (el contrato no ha cambiado)")
    @GetMapping("/firmas")
    public FirmaService.Estado estado(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return firmas.estado(id, actor);
    }

    @Operation(summary = "Firma de una parte (imagen PNG del trazo). El inquilino solo firma como ARRENDATARIO")
    @PostMapping(value = "/firmas/{parte}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public FirmaService.Estado firmar(@PathVariable Integer id, @PathVariable Parte parte, @RequestParam("archivo") MultipartFile imagen,
                                      HttpServletRequest peticion, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return firmas.firmar(id, parte, imagen, peticion.getRemoteAddr(), actor);
    }

    @Operation(summary = "Contrato en PDF con la hoja de firmas")
    @GetMapping(value = "/pdf-firmado", produces = MediaType.APPLICATION_PDF_VALUE)
    public ResponseEntity<byte[]> pdfFirmado(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        var pdf = firmas.pdfFirmado(id, actor);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(pdf.nombreArchivo(), StandardCharsets.UTF_8).build().toString())
                .body(pdf.contenido());
    }
}
