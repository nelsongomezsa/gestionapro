package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.ResumenFiscalService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;

@Tag(name = "Resumen fiscal", description = "Orientativo: ingresos, gastos deducibles, amortizaciones y rendimiento neto de un piso")
@RestController
@RequestMapping("/api/pisos/{id}/resumen-fiscal")
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class ResumenFiscalController {

    private final ResumenFiscalService servicio;

    public ResumenFiscalController(ResumenFiscalService servicio) {
        this.servicio = servicio;
    }

    @Operation(summary = "Resumen del año (JSON)", description = "Valores catastrales del recibo del IBI, para la amortización.")
    @GetMapping
    public ResumenFiscalService.Resumen resumen(@PathVariable Integer id, @RequestParam int anio,
                                                @RequestParam(required = false) BigDecimal valorCatastral,
                                                @RequestParam(required = false) BigDecimal valorCatastralConstruccion,
                                                @AuthenticationPrincipal UsuarioAutenticado actor) {
        return servicio.calcular(id, anio, valorCatastral, valorCatastralConstruccion, actor);
    }

    @Operation(summary = "El mismo resumen en PDF o CSV")
    @GetMapping("/{formato:pdf|csv}")
    public ResponseEntity<byte[]> archivo(@PathVariable Integer id, @PathVariable String formato, @RequestParam int anio,
                                         @RequestParam(required = false) BigDecimal valorCatastral,
                                         @RequestParam(required = false) BigDecimal valorCatastralConstruccion,
                                         @AuthenticationPrincipal UsuarioAutenticado actor) {
        var r = servicio.calcular(id, anio, valorCatastral, valorCatastralConstruccion, actor);
        var a = formato.equals("pdf") ? servicio.pdf(r) : servicio.csv(r);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(a.tipo() + (formato.equals("csv") ? ";charset=UTF-8" : "")))
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment()
                        .filename(a.nombre(), StandardCharsets.UTF_8).build().toString())
                .body(a.contenido());
    }
}
