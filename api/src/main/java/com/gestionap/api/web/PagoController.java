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
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.YearMonth;
import java.util.List;

@Tag(name = "Pagos", description = "Un PROPIETARIO ve los de sus pisos; un INQUILINO, solo los suyos")
@RestController
@RequestMapping("/api/pagos")
public class PagoController {

    private final PagoService pagos;

    public PagoController(PagoService pagos) {
        this.pagos = pagos;
    }

    @Operation(summary = "Lista, opcionalmente de un mes (aaaa-mm) y de un inquilino")
    @GetMapping
    public List<PagoResponse> listar(@Parameter(example = "2026-10") @RequestParam(required = false) YearMonth mes,
                                     @RequestParam(required = false) Integer inquilino,
                                     @AuthenticationPrincipal UsuarioAutenticado actor) {
        return pagos.listar(mes, inquilino, actor);
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
}
