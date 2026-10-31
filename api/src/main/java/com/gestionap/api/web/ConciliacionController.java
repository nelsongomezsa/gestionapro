package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.ConciliacionService;
import com.gestionap.api.web.dto.ConciliacionDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.YearMonth;

/** Endpoints para analizar extractos y confirmar sus pagos. */
@Tag(name = "Conciliación", description = "Propuestas de pagos a partir de extractos CSV")
@RestController
@RequestMapping("/api/conciliacion")
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class ConciliacionController {

    private final ConciliacionService conciliacion;

    public ConciliacionController(ConciliacionService conciliacion) {
        this.conciliacion = conciliacion;
    }

    @Operation(summary = "Analiza un extracto CSV y propone contratos")
    @PostMapping("/analizar")
    public ConciliacionDtos.Analisis analizar(@RequestPart("archivo") MultipartFile archivo,
                                               @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM") YearMonth mes,
                                               @AuthenticationPrincipal UsuarioAutenticado actor) {
        return conciliacion.analizar(archivo, mes, actor);
    }

    @Operation(summary = "Confirma los pagos seleccionados y emite sus recibos")
    @PostMapping("/confirmar")
    public ConciliacionDtos.ConfirmarResponse confirmar(@RequestBody ConciliacionDtos.ConfirmarRequest request,
                                                         @AuthenticationPrincipal UsuarioAutenticado actor) {
        return new ConciliacionDtos.ConfirmarResponse(conciliacion.confirmar(request.pagos(), actor));
    }
}
