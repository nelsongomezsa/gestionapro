package com.gestionap.api.service;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Cálculos de rentabilidad financiera de un piso: inversión total, cuota de
 * hipoteca, rentabilidad bruta/neta, cash flow mensual, cash-on-cash, capital
 * propio, plusvalía latente y PER inmobiliario.
 *
 * <p>Copiado de la app de escritorio (com.gestionap.service.CalculadoraFinancieraPiso)
 * sin cambiar ningún cálculo. Únicas diferencias: el campo {@code rocePct} se
 * llama aquí {@code cashOnCashPct}, que es lo que realmente mide (cash flow
 * anual / capital propio); y no se incluyen parse()/parseInt(), que solo
 * servían para leer TextFields de JavaFX. CalculadoraFinancieraPisoTest
 * contiene los mismos casos que los tests de escritorio.
 *
 * <p>TODO: añadir el ROCE de verdad (beneficio operativo antes de intereses e
 * impuestos / capital empleado) como métrica aparte, sin tocar cashOnCashPct.
 *
 * <p>Replica el comportamiento del cálculo original de AnalisisPisosController,
 * con una corrección deliberada: {@code rentabilidadNetaPct} no resta la
 * cuota de hipoteca (ver comentario en {@link #calcular}). Incluye además
 * una particularidad heredada del original: los campos {@code rentabilidadBrutaPct},
 * {@code rentabilidadNetaPct} y {@code calificacion} vienen {@code null}
 * cuando {@code inversionTotal <= 0} (no son calculables), y
 * {@code cashOnCashPct} viene {@code null} cuando {@code capitalPropio <= 0}, y
 * {@code perAnios} viene {@code null} cuando los ingresos anuales son 0 —
 * el llamador decide qué hacer en esos casos (el controller original, ante
 * un valor null, no actualiza el Label correspondiente y deja el valor
 * previamente mostrado).
 */
public final class CalculadoraFinancieraPiso {

    private CalculadoraFinancieraPiso() {}

    public enum Calificacion { EXCELENTE, ACEPTABLE, A_REVISAR }

    public record DatosAdquisicion(
            BigDecimal precioCompra,
            BigDecimal itpPagado,
            BigDecimal gastosNotaria,
            BigDecimal gastosRegistro,
            BigDecimal costeReforma,
            BigDecimal costeMobiliario,
            BigDecimal otrosGastosCompra) {

        public BigDecimal total() {
            return precioCompra.add(itpPagado).add(gastosNotaria).add(gastosRegistro)
                    .add(costeReforma).add(costeMobiliario).add(otrosGastosCompra);
        }
    }

    public record DatosHipoteca(boolean activa, BigDecimal importe, BigDecimal tipoInteresAnualPct, int plazoAnos) {}

    public record DatosGastos(
            BigDecimal ibiAnual,
            BigDecimal comunidadMensual,
            BigDecimal seguroAnual,
            BigDecimal mantenimientoAnual) {

        public BigDecimal totalAnual() {
            return ibiAnual.add(comunidadMensual.multiply(BigDecimal.valueOf(12)))
                    .add(seguroAnual).add(mantenimientoAnual);
        }
    }

    public record Entrada(
            DatosAdquisicion adquisicion,
            DatosHipoteca hipoteca,
            DatosGastos gastos,
            BigDecimal valorMercadoActual,
            BigDecimal ingresosMes) {}

    public record Resultado(
            BigDecimal inversionTotal,
            BigDecimal cuotaMensualHipoteca,
            BigDecimal totalGastosAnuales,
            Double rentabilidadBrutaPct,
            Double rentabilidadNetaPct,
            Calificacion calificacion,
            BigDecimal cashFlowMensual,
            Double cashOnCashPct,
            BigDecimal capitalPropio,
            BigDecimal plusvaliaLatente,
            Double perAnios) {}

    public static Resultado calcular(Entrada e) {
        BigDecimal invTotal = e.adquisicion().total();

        BigDecimal cuota = e.hipoteca().activa()
                ? cuotaMensual(e.hipoteca().importe(), e.hipoteca().tipoInteresAnualPct(), e.hipoteca().plazoAnos())
                : BigDecimal.ZERO;

        BigDecimal totalGastosAnuales = e.gastos().totalAnual();

        BigDecimal ingresosAnuales = e.ingresosMes().multiply(BigDecimal.valueOf(12));
        BigDecimal importeHipEfectivo = importeHipotecaEfectivo(e.hipoteca().activa(), e.hipoteca().importe());
        BigDecimal capitalPropio = invTotal.subtract(importeHipEfectivo);

        Double rentBruta = null;
        Double rentNeta = null;
        Calificacion calificacion = null;
        if (invTotal.compareTo(BigDecimal.ZERO) > 0) {
            rentBruta = ingresosAnuales.divide(invTotal, 6, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100)).doubleValue();
            // Rentabilidad neta = (ingresos - gastos operativos) / inversión total.
            // NO resta la cuota de hipoteca: es una métrica "antes de financiación",
            // comparable entre compra al contado y apalancada — la financiación ya
            // se refleja por separado en cashFlowMensual y en cashOnCashPct (cash-on-cash
            // sobre capitalPropio). Antes de esta corrección (2026-08-11, al unificar
            // con la implementación duplicada de RentabilidadController) sí se
            // restaba la hipoteca aquí mientras se dividía entre la inversión TOTAL
            // (no el capital propio): mezclaba un numerador apalancado con un
            // denominador no apalancado, dando valores absurdos con plazos cortos o
            // financiación alta (p. ej. -50% con un plazo de amortización de 1 año).
            // Casos de referencia en CalculadoraFinancieraPisoTest ("Fase 0 paso 3").
            rentNeta = ingresosAnuales.subtract(totalGastosAnuales)
                    .divide(invTotal, 6, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100)).doubleValue();
            calificacion = rentBruta > 7 ? Calificacion.EXCELENTE
                    : rentBruta >= 5 ? Calificacion.ACEPTABLE
                    : Calificacion.A_REVISAR;
        }

        BigDecimal gastosMes = totalGastosAnuales.divide(BigDecimal.valueOf(12), 2, RoundingMode.HALF_UP);
        BigDecimal cfMes = e.ingresosMes().subtract(cuota).subtract(gastosMes);

        Double cashOnCash = null;
        if (capitalPropio.compareTo(BigDecimal.ZERO) > 0) {
            cashOnCash = cfMes.multiply(BigDecimal.valueOf(12))
                    .divide(capitalPropio, 6, RoundingMode.HALF_UP)
                    .multiply(BigDecimal.valueOf(100)).doubleValue();
        }

        BigDecimal plusvalia = e.valorMercadoActual().subtract(invTotal);

        Double per = null;
        if (ingresosAnuales.compareTo(BigDecimal.ZERO) > 0) {
            per = invTotal.divide(ingresosAnuales, 2, RoundingMode.HALF_UP).doubleValue();
        }

        return new Resultado(invTotal, cuota, totalGastosAnuales,
                rentBruta, rentNeta, calificacion,
                cfMes, cashOnCash, capitalPropio, plusvalia, per);
    }

    /**
     * Importe de hipoteca a usar en cualquier cálculo o guardado: si la
     * hipoteca no está activa, es 0 SIEMPRE, sin importar qué texto haya
     * quedado en el campo (p. ej. el usuario desmarcó "Tiene hipoteca" pero
     * no borró el importe). Única fuente de verdad para esta regla — tanto
     * calcular() como quien guarda los datos deben pasar por aquí, para que
     * no puedan divergir entre sí.
     */
    public static BigDecimal importeHipotecaEfectivo(boolean hipotecaActiva, BigDecimal importe) {
        return hipotecaActiva ? importe : BigDecimal.ZERO;
    }

    /** Cuota mensual de una hipoteca a cuota fija (amortización francesa). */
    public static BigDecimal cuotaMensual(BigDecimal principal, BigDecimal tasaAnualPct, int plazoAnos) {
        if (principal == null || tasaAnualPct == null || plazoAnos <= 0
                || principal.compareTo(BigDecimal.ZERO) == 0) return BigDecimal.ZERO;
        double p = principal.doubleValue();
        double r = tasaAnualPct.doubleValue() / 100.0 / 12.0;
        int n = plazoAnos * 12;
        if (r == 0) return BigDecimal.valueOf(p / n).setScale(2, RoundingMode.HALF_UP);
        double m = p * r * Math.pow(1 + r, n) / (Math.pow(1 + r, n) - 1);
        return BigDecimal.valueOf(m).setScale(2, RoundingMode.HALF_UP);
    }
}
