package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.ArchivoService;
import com.gestionap.api.service.GastoService;
import com.gestionap.api.web.dto.GastoDtos.GastoRequest;
import com.gestionap.api.web.dto.GastoDtos.GastoResponse;
import com.gestionap.api.web.dto.GastoDtos.ResumenGastos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

/** Endpoints de gastos reales por piso. */
@Tag(name = "Gastos", description = "Gastos reales y sus facturas por piso")
@RestController
@RequestMapping("/api/gastos")
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class GastoController {

    private final GastoService gastos;

    public GastoController(GastoService gastos) {
        this.gastos = gastos;
    }

    @Operation(summary = "Lista gastos y totales, opcionalmente por piso y año")
    @GetMapping
    public ResumenGastos listar(@RequestParam(required = false) Integer piso,
                                @RequestParam(required = false) Integer anio,
                                @AuthenticationPrincipal UsuarioAutenticado actor) {
        return gastos.listar(piso, anio, actor);
    }

    @Operation(summary = "Crea un gasto del piso")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public GastoResponse crear(@Valid @RequestBody GastoRequest req,
                               @AuthenticationPrincipal UsuarioAutenticado actor) {
        return gastos.crear(req, actor);
    }

    @Operation(summary = "Actualiza un gasto manual")
    @PutMapping("/{id}")
    public GastoResponse actualizar(@PathVariable Integer id, @Valid @RequestBody GastoRequest req,
                                    @AuthenticationPrincipal UsuarioAutenticado actor) {
        return gastos.actualizar(id, req, actor);
    }

    @Operation(summary = "Borra un gasto manual")
    @DeleteMapping("/{id}")
    public void borrar(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        gastos.borrar(id, actor);
    }

    @Operation(summary = "Adjunta una factura")
    @PostMapping(value = "/{id}/factura", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public GastoResponse subirFactura(@PathVariable Integer id, @RequestPart("archivo") MultipartFile archivo,
                                      @AuthenticationPrincipal UsuarioAutenticado actor) {
        return gastos.subirFactura(id, archivo, actor);
    }

    @Operation(summary = "Descarga la factura")
    @GetMapping("/{id}/factura")
    public ResponseEntity<byte[]> factura(@PathVariable Integer id,
                                          @AuthenticationPrincipal UsuarioAutenticado actor) {
        ArchivoService.Contenido contenido = gastos.factura(id, actor);
        return ResponseEntity.ok().header(HttpHeaders.CONTENT_TYPE, contenido.tipo()).body(contenido.datos());
    }
}
