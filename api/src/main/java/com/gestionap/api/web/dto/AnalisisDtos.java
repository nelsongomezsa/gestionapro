package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/** Estadísticas de un periodo, de la cartera, un piso o una habitación. */
public final class AnalisisDtos {
    private AnalisisDtos() {}

    public record AnalisisResponse(
            LocalDate desde,
            LocalDate hasta,
            @Schema(description = "Ámbito: CARTERA, PISO o HABITACION") String ambito,
            Totales actual,
            @Schema(description = "El mismo periodo un año antes") Totales anterior,
            @Schema(description = "Ingresos, gastos y ocupación por piso, ordenados por resultado neto (ranking)") List<PisoAnalisis> pisos,
            @Schema(description = "Ingresos, gastos y ocupación de cada mes del periodo") List<MesAnalisis> meses,
            @Schema(description = "Inquilinos con meses debidos en el periodo, de más a menos importe impagado") List<Morosidad> morosidad) {}

    public record Totales(
            BigDecimal ingresos,
            BigDecimal gastos,
            BigDecimal neto,
            @Schema(description = "Días-habitación alquilados / días-habitación del periodo, en %") double ocupacionPct,
            @Schema(description = "Media de días sin contrato por habitación") double diasMediosVacia,
            int habitaciones,
            int contratosIniciados,
            int contratosFinalizados,
            @Schema(description = "Duración media de los contratos finalizados, en meses") Double duracionMediaMeses,
            @Schema(description = "Contratos finalizados / habitaciones, en %") double rotacionPct,
            @Schema(description = "Rentas de meses vencidos sin ningún pago") BigDecimal impagado) {}

    public record PisoAnalisis(PisoBreve piso, BigDecimal ingresos, BigDecimal gastos, BigDecimal neto,
                               double ocupacionPct, double diasMediosVacia, int habitaciones) {}

    public record MesAnalisis(@Schema(example = "2026-10") String mes, @Schema(example = "oct") String etiqueta,
                              BigDecimal ingresos, BigDecimal gastos,
                              @Schema(description = "Ausente en los meses que aún no han empezado") Double ocupacionPct) {}

    public record Morosidad(Integer idInquilino, String nombre, int mesesDebidos, int mesesImpagados,
                            @Schema(description = "Meses pagados después del día 5") int pagosFueraDePlazo,
                            BigDecimal importeImpagado,
                            @Schema(description = "Meses pagados a tiempo / meses debidos, en %") double puntualidadPct) {}
}
