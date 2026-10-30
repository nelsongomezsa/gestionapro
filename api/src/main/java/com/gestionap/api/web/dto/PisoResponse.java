package com.gestionap.api.web.dto;

import com.gestionap.api.service.CalculadoraFinancieraPiso.Calificacion;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;

public record PisoResponse(
        Integer id,
        String direccion,
        CiudadResponse ciudad,
        int numeroHabitaciones,
        Integer idPropietario,
        Ocupacion ocupacion,
        @Schema(description = "Suma de las rentas de los contratos activos hoy")
        BigDecimal ingresosMensuales,
        DatosFinancierosDto datosFinancieros,
        @Schema(description = "null si el piso no tiene datos financieros")
        Metricas metricas) {

    public record Ocupacion(long total, long alquiladas, long disponibles, long mantenimiento) {}

    /** Resultado de CalculadoraFinancieraPiso. Los porcentajes vienen null cuando no son calculables. */
    public record Metricas(
            BigDecimal inversionTotal,
            BigDecimal cuotaMensualHipoteca,
            BigDecimal gastosAnuales,
            Double rentabilidadBrutaPct,
            Double rentabilidadNetaPct,
            Calificacion calificacion,
            BigDecimal cashFlowMensual,
            @Schema(description = "Cash flow anual / capital propio (cash-on-cash). En el escritorio se llamaba ROCE")
            Double cashOnCashPct,
            BigDecimal capitalPropio,
            BigDecimal plusvaliaLatente,
            Double perAnios,
            boolean gastosReales) {}
}
