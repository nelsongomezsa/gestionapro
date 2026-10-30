package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.InformeMensualPdf;
import com.gestionap.api.service.PanelService;
import com.gestionap.api.web.dto.PanelDtos.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.time.YearMonth;
import java.util.List;

@Tag(name = "Inicio, estadísticas y calendario", description = "Filtrado por propietario; meses siempre en español")
@RestController
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class PanelController {

    private final PanelService panel;
    private final InformeMensualPdf informe;

    public PanelController(PanelService panel, InformeMensualPdf informe) {
        this.panel = panel;
        this.informe = informe;
    }

    @Operation(summary = "Inicio: ocupación, cobrado del mes con tendencia, cash flow, gráfico de 6 meses, alertas, vencimientos y actividad")
    @GetMapping("/api/dashboard")
    public DashboardResponse dashboard(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return panel.dashboard(actor);
    }

    @Operation(summary = "Ingresos de 12 meses, ocupación, incidencias de 6 meses e ingresos anuales")
    @GetMapping("/api/estadisticas")
    public EstadisticasResponse estadisticas(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return panel.estadisticas(actor);
    }

    @Operation(summary = "Calendario del mes: estado de cada día (pagado, esperado, vencido), pagos y fines de contrato")
    @GetMapping("/api/calendario")
    public CalendarioResponse calendario(@Parameter(example = "2026-10") @RequestParam(required = false) YearMonth mes,
                                         @AuthenticationPrincipal UsuarioAutenticado actor) {
        return panel.calendario(mes != null ? mes : YearMonth.now(), actor);
    }

    @Operation(summary = "Actividad reciente: la de todos para el admin (salvo soloMia), la propia para un propietario")
    @GetMapping("/api/actividad")
    public List<ActividadResponse> actividad(@RequestParam(defaultValue = "20") int limite,
                                             @RequestParam(defaultValue = "false") boolean soloMia,
                                             @AuthenticationPrincipal UsuarioAutenticado actor) {
        return panel.actividadReciente(actor, Math.clamp(limite, 1, 100), soloMia);
    }

    @Operation(summary = "Informe mensual en PDF (resumen, contratos, pagos e incidencias)")
    @GetMapping(value = "/api/informes/mensual", produces = MediaType.APPLICATION_PDF_VALUE)
    public ResponseEntity<byte[]> informeMensual(@Parameter(example = "2026-10") @RequestParam(required = false) YearMonth mes,
                                                 @AuthenticationPrincipal UsuarioAutenticado actor) {
        var pdf = informe.generar(mes != null ? mes : YearMonth.now(), actor);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(pdf.nombreArchivo(), StandardCharsets.UTF_8).build().toString())
                .body(pdf.contenido());
    }
}
