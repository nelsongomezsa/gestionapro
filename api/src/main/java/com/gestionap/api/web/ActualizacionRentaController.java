package com.gestionap.api.web;

import com.gestionap.api.domain.ActualizacionRenta.Indice;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.ActualizacionRentaService;
import com.gestionap.api.web.dto.ActualizacionRentaDtos.Confirmacion;
import com.gestionap.api.web.dto.ActualizacionRentaDtos.Historial;
import com.gestionap.api.web.dto.ActualizacionRentaDtos.Propuesta;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Actualización de renta", description = "Propuesta con el IRAV o el IPC del INE, confirmación del propietario e historial")
@RestController
@RequestMapping("/api/contratos/{id}")
public class ActualizacionRentaController {

    private final ActualizacionRentaService servicio;

    public ActualizacionRentaController(ActualizacionRentaService servicio) {
        this.servicio = servicio;
    }

    @Operation(summary = "Propuesta para el próximo aniversario (orientativa)",
            description = "Sin índice, el recomendado por la fecha del contrato: IRAV desde el 26-05-2023, IPC antes.")
    @GetMapping("/actualizacion-renta")
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public Propuesta propuesta(@PathVariable Integer id, @RequestParam(required = false) Indice indice,
                               @AuthenticationPrincipal UsuarioAutenticado actor) {
        return servicio.propuesta(id, indice, actor);
    }

    @Operation(summary = "Confirma la actualización: cambia la renta del contrato y queda en el historial")
    @PostMapping("/actualizacion-renta")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
    public Historial confirmar(@PathVariable Integer id, @Valid @RequestBody Confirmacion req,
                               @AuthenticationPrincipal UsuarioAutenticado actor) {
        return servicio.confirmar(id, req, actor);
    }

    @Operation(summary = "Historial de actualizaciones (también para el inquilino del contrato)")
    @GetMapping("/actualizaciones-renta")
    public List<Historial> historial(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return servicio.historial(id, actor);
    }
}
