package com.gestionap.api.web;

import com.gestionap.api.config.ItpProperties;
import com.gestionap.api.service.CalculadoraRentabilidad;
import com.gestionap.api.web.dto.ItpResponse;
import com.gestionap.api.web.dto.RentabilidadRequest;
import com.gestionap.api.web.dto.RentabilidadResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.RoundingMode;

@Tag(name = "Calculadora", description = "Pantalla \"Rentabilidad\" del escritorio")
@RestController
@RequestMapping("/api/calculadora")
@PreAuthorize("hasAnyRole('PROPIETARIO', 'ADMIN')")
public class CalculadoraController {

    private final CalculadoraRentabilidad calculadora;
    private final ItpProperties itp;

    public CalculadoraController(CalculadoraRentabilidad calculadora, ItpProperties itp) {
        this.calculadora = calculadora;
        this.itp = itp;
    }

    @Operation(summary = "Rentabilidad de una compra para alquilar (ITP por CCAA, hipoteca, cash flow...)",
            description = "Los campos opcionales omitidos cuentan como 0, como un campo vacío en el escritorio.")
    @PostMapping("/rentabilidad")
    public RentabilidadResponse rentabilidad(@Valid @RequestBody RentabilidadRequest req) {
        return calculadora.responder(req);
    }

    @Operation(summary = "Tipos de ITP por comunidad autónoma (itp-rates.yml)")
    @GetMapping("/itp")
    public ItpResponse itp() {
        return new ItpResponse(itp.anioReferencia(), itp.comunidades().stream()
                .map(c -> new ItpResponse.Comunidad(c.nombre(), c.tipo())).toList());
    }
}
