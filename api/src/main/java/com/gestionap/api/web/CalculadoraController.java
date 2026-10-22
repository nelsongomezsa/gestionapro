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
        var r = calculadora.calcular(new CalculadoraRentabilidad.Entrada(
                req.comunidad(), req.precioCompra(), nz(req.gastosNotariaRegistro()), nz(req.gastosHipoteca()),
                nz(req.reforma()), nz(req.comisionCompra()), nz(req.mobiliario()),
                nz(req.ibiMensual()), nz(req.segurosMensual()), nz(req.comunidadMensual()),
                nz(req.mantenimientoMensual()), nz(req.vacioMensual()), req.alquilerMensual(),
                nz(req.revalorizacionAnualPct()), nz(req.porcentajeFinanciado()),
                req.plazoAnos() != null ? req.plazoAnos() : 0, nz(req.tipoInteresPct())));
        return new RentabilidadResponse(
                r2(r.itpPct()), r2(r.itpImporte()), r2(r.totalCompra()), r2(r.gastosMensuales()),
                r2(r.gastosAnuales()), r2(r.alquilerAnual()), r2(r.hipoteca()), r2(r.capitalAportado()),
                r2(r.cuotaMensual()), r2(r.interesesMensualesPromedio()), r2(r.amortizacionMensualPromedio()),
                r2(r.rentabilidadBrutaPct()), r2(r.rentabilidadNetaPct()), r2(r.cashFlowMensual()),
                r2(r.cashFlowAnual()), r2(r.aniosRecuperacion()), r2(r.plusvalia5Anios()), r2(r.plusvalia10Anios()));
    }

    @Operation(summary = "Tipos de ITP por comunidad autónoma (itp-rates.yml)")
    @GetMapping("/itp")
    public ItpResponse itp() {
        return new ItpResponse(itp.anioReferencia(), itp.comunidades().stream()
                .map(c -> new ItpResponse.Comunidad(c.nombre(), c.tipo())).toList());
    }

    private static double nz(Double v) {
        return v != null ? v : 0;
    }

    private static BigDecimal r2(Double v) {
        return v == null ? null : BigDecimal.valueOf(v).setScale(2, RoundingMode.HALF_UP);
    }
}
