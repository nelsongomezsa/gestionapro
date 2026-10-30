package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.PagoService;
import com.gestionap.api.web.dto.PagoRequest;
import com.gestionap.api.web.dto.PagoResponse;
import com.gestionap.api.web.dto.ResumenPagosResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import com.gestionap.api.service.ReciboService;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;

@Tag(name = "Pagos", description = "Un PROPIETARIO ve los de sus pisos; un INQUILINO, solo los suyos")
@RestController
@RequestMapping("/api/pagos")
public class PagoController {

    private final PagoService pagos;
    private final ReciboService recibos;

    public PagoController(PagoService pagos, ReciboService recibos) {
        this.pagos = pagos;
        this.recibos = recibos;
    }

    @Operation(summary = "Lista, opcionalmente de un mes (aaaa-mm), de un inquilino y de un piso")
    @GetMapping
    public List<PagoResponse> listar(@Parameter(example = "2026-10") @RequestParam(required = false) YearMonth mes,
                                     @RequestParam(required = false) Integer inquilino,
                                     @RequestParam(required = false) Integer piso,
                                     @AuthenticationPrincipal UsuarioAutenticado actor) {
        return pagos.listar(mes, inquilino, piso, actor);
    }

    @Operation(summary = "Esperado, cobrado y pendiente del mes, con los contratos sin pago")
    @GetMapping("/resumen")
    public ResumenPagosResponse resumen(@Parameter(example = "2026-10") @RequestParam(required = false) YearMonth mes,
                                        @AuthenticationPrincipal UsuarioAutenticado actor) {
        return pagos.resumen(mes != null ? mes : YearMonth.now(), actor);
    }

    @Operation(summary = "Registra un pago de un contrato activo")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public PagoResponse registrar(@Valid @RequestBody PagoRequest req, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return pagos.registrar(req, actor);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public void borrar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        pagos.borrar(id, actor);
    }

    @Operation(summary = "Recibo del pago en PDF, numerado por propietario y año",
            description = "Para el ADMIN, el propietario del piso o el inquilino del pago. Si el pago aún no tenía número "
                    + "(registrado desde el escritorio), se le asigna ahora.")
    @GetMapping(value = "/{id}/recibo", produces = MediaType.APPLICATION_PDF_VALUE)
    public ResponseEntity<byte[]> recibo(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        ReciboService.Pdf pdf = recibos.pdf(id, actor);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(pdf.nombreArchivo(), StandardCharsets.UTF_8).build().toString())
                .body(pdf.contenido());
    }

    @Operation(summary = "Envía el recibo por email al inquilino",
            description = "enviado=false si el email del servidor no está configurado (MAIL_HOST...).")
    @PostMapping("/{id}/recibo/enviar")
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public Map<String, Boolean> enviarRecibo(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return Map.of("enviado", recibos.enviar(id, actor));
    }
}
