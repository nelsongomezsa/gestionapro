package com.gestionap.api.service;

import com.gestionap.api.config.ItpProperties;
import com.gestionap.api.web.ApiException;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;

/**
 * Calculadora de rentabilidad de una compra para alquilar: la pantalla
 * "Rentabilidad" del escritorio (RentabilidadController.recalcular()).
 *
 * <p>Las operaciones se copian tal cual, en double, y en el mismo orden que en
 * el escritorio, para dar exactamente los mismos resultados (ver
 * CalculadoraRentabilidadTest, cuyos valores esperados salen de ejecutar el
 * controlador real). Inversión, cuota, gastos, rentabilidades y cash flow se
 * delegan en {@link CalculadoraFinancieraPiso}; el ITP por CCAA, el %
 * financiado, la revalorización y el desglose de la cuota son propios de esta
 * pantalla.
 *
 * <p>Única diferencia de presentación: donde el escritorio muestra "—" (años
 * para recuperar o plusvalías no calculables) la API devuelve null.
 */
@Service
public class CalculadoraRentabilidad {

    public record Entrada(
            String comunidad,
            double precioCompra,
            double gastosNotariaRegistro,
            double gastosHipoteca,
            double reforma,
            double comisionCompra,
            double mobiliario,
            double ibiMensual,
            double segurosMensual,
            double comunidadMensual,
            double mantenimientoMensual,
            double vacioMensual,
            double alquilerMensual,
            double revalorizacionAnualPct,
            double porcentajeFinanciado,
            int plazoAnos,
            double tipoInteresPct) {}

    public record Resultado(
            double itpPct,
            double itpImporte,
            double totalCompra,
            double gastosMensuales,
            double gastosAnuales,
            double alquilerAnual,
            double hipoteca,
            double capitalAportado,
            double cuotaMensual,
            double interesesMensualesPromedio,
            double amortizacionMensualPromedio,
            double rentabilidadBrutaPct,
            double rentabilidadNetaPct,
            double cashFlowMensual,
            double cashFlowAnual,
            Double aniosRecuperacion,
            Double plusvalia5Anios,
            Double plusvalia10Anios) {}

    private final ItpProperties itp;

    public CalculadoraRentabilidad(ItpProperties itp) {
        this.itp = itp;
    }

    public Resultado calcular(Entrada e) {
        double itpPct = itp.tipoDe(e.comunidad()).orElseThrow(() -> ApiException.badRequest(
                "COMUNIDAD_DESCONOCIDA", "Comunidad autónoma desconocida: " + e.comunidad()));
        double precioCompra = e.precioCompra();
        double itpImporte = precioCompra * itpPct / 100.0;

        double ibi = e.ibiMensual();
        double seg = e.segurosMensual();
        double com = e.comunidadMensual();
        double mant = e.mantenimientoMensual();
        double vac = e.vacioMensual();
        double gastosMensual = ibi + seg + com + mant + vac;

        double alquilerMensual = e.alquilerMensual();
        double alquilerAnual = alquilerMensual * 12;

        double revalorizacion = e.revalorizacionAnualPct();
        Double plusvalia5 = null;
        Double plusvalia10 = null;
        if (precioCompra > 0 && revalorizacion > 0) {
            plusvalia5 = precioCompra * (Math.pow(1 + revalorizacion / 100.0, 5) - 1);
            plusvalia10 = precioCompra * (Math.pow(1 + revalorizacion / 100.0, 10) - 1);
        }

        double hipoteca = precioCompra * (e.porcentajeFinanciado() / 100.0);
        int plazo = e.plazoAnos();

        var adquisicion = new CalculadoraFinancieraPiso.DatosAdquisicion(
                BigDecimal.valueOf(precioCompra), BigDecimal.valueOf(itpImporte),
                BigDecimal.valueOf(e.gastosNotariaRegistro()), BigDecimal.ZERO,
                BigDecimal.valueOf(e.reforma()), BigDecimal.valueOf(e.mobiliario()),
                BigDecimal.valueOf(e.gastosHipoteca() + e.comisionCompra()));
        var datosHipoteca = new CalculadoraFinancieraPiso.DatosHipoteca(
                hipoteca > 0, BigDecimal.valueOf(hipoteca), BigDecimal.valueOf(e.tipoInteresPct()), plazo);
        var datosGastos = new CalculadoraFinancieraPiso.DatosGastos(
                BigDecimal.valueOf(ibi * 12), BigDecimal.valueOf(com),
                BigDecimal.valueOf(seg * 12), BigDecimal.valueOf((mant + vac) * 12));
        var entrada = new CalculadoraFinancieraPiso.Entrada(
                adquisicion, datosHipoteca, datosGastos, BigDecimal.ZERO, BigDecimal.valueOf(alquilerMensual));
        CalculadoraFinancieraPiso.Resultado r = CalculadoraFinancieraPiso.calcular(entrada);

        double totalCompra = r.inversionTotal().doubleValue();
        double capitalAportado = r.capitalPropio().doubleValue();
        double cuotaMensual = r.cuotaMensualHipoteca().doubleValue();
        double gastosAnual = r.totalGastosAnuales().doubleValue();
        double cashFlowMensual = r.cashFlowMensual().doubleValue();
        double cashFlowAnual = cashFlowMensual * 12;
        Double aniosRecuperar = (cashFlowAnual > 0 && capitalAportado > 0)
                ? capitalAportado / cashFlowAnual : null;

        // Como en el escritorio: si no son calculables (inversión 0) se muestran como 0.
        double rentBruta = r.rentabilidadBrutaPct() != null ? r.rentabilidadBrutaPct() : 0;
        double rentNeta = r.rentabilidadNetaPct() != null ? r.rentabilidadNetaPct() : 0;

        // Desglose medio de la cuota, derivado de la cuota total (no lo da CalculadoraFinancieraPiso).
        double interesesMensual = 0;
        double amortizacionMensual = 0;
        int n = plazo * 12;
        if (hipoteca > 0 && n > 0) {
            double totalIntereses = cuotaMensual * n - hipoteca;
            interesesMensual = totalIntereses / n;
            amortizacionMensual = cuotaMensual - interesesMensual;
        }

        return new Resultado(itpPct, itpImporte, totalCompra, gastosMensual, gastosAnual,
                alquilerAnual, hipoteca, capitalAportado, cuotaMensual,
                interesesMensual, amortizacionMensual, rentBruta, rentNeta,
                cashFlowMensual, cashFlowAnual, aniosRecuperar, plusvalia5, plusvalia10);
    }
}
