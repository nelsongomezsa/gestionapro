package com.gestionap.api.service;

import com.gestionap.api.service.CalculadoraFinancieraPiso.*;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Valores de referencia calculados de forma independiente (Python, no
 * re-derivando la misma fórmula en Java) antes de escribir estos tests,
 * para verificar que la extracción no cambió ningún resultado respecto al
 * cálculo original que vivía en AnalisisPisosController.
 *
 * <p>Copia de CalculadoraFinancieraPisoTest de la app de escritorio, con los
 * mismos valores esperados: si pasan aquí, la API da los mismos resultados.
 * Solo cambia el nombre rocePct -> cashOnCashPct y se omiten los tests de
 * parse()/parseInt(), que no existen en la API.
 */
class CalculadoraFinancieraPisoTest {

    // ── importeHipotecaEfectivo() ────────────────────────────────
    // Bug real: el guardado de datos financieros parseaba y guardaba
    // importeHipoteca/cuotaMensualHipoteca del texto de los campos sin
    // mirar el checkbox "Tiene hipoteca", mientras que el recálculo en
    // vivo sí lo hacía — si el usuario desmarcaba la casilla sin borrar
    // los campos, se guardaba un importe/cuota distintos de cero con
    // tieneHipoteca=false. Corregido centralizando la regla aquí y
    // haciendo que tanto calcular() como el guardado pasen por ella.

    @Test
    void importeHipotecaEfectivo_hipotecaInactiva_devuelveCero_aunqueElCampoTengaTexto() {
        // Simula: checkbox "Tiene hipoteca" desmarcado, pero el campo de
        // importe todavía tiene un valor sin borrar (80000).
        BigDecimal resultado = CalculadoraFinancieraPiso.importeHipotecaEfectivo(
                false, new BigDecimal("80000"));

        assertEquals(0, BigDecimal.ZERO.compareTo(resultado));
    }

    @Test
    void importeHipotecaEfectivo_hipotecaActiva_devuelveElImporteTalCual() {
        BigDecimal resultado = CalculadoraFinancieraPiso.importeHipotecaEfectivo(
                true, new BigDecimal("80000"));

        assertEquals(0, new BigDecimal("80000").compareTo(resultado));
    }

    @Test
    void guardarConHipotecaDesmarcada_importeYCuotaQuedanEnCero_aunqueLosCamposTenganTexto() {
        // Reproduce el flujo completo de guardado tal como lo hace ahora
        // AnalisisPisosController.abrirDialogoDatosFinancieros(): el
        // usuario desmarcó "Tiene hipoteca" pero dejó importe/tipo/plazo
        // con valores de una edición anterior.
        boolean hipotecaActiva = false;
        BigDecimal importeEnElCampo = new BigDecimal("80000");
        BigDecimal tipoInteresEnElCampo = new BigDecimal("3.0");
        int plazoEnElCampo = 20;

        BigDecimal importeGuardado = CalculadoraFinancieraPiso.importeHipotecaEfectivo(
                hipotecaActiva, importeEnElCampo);
        BigDecimal cuotaGuardada = CalculadoraFinancieraPiso.cuotaMensual(
                importeGuardado, tipoInteresEnElCampo, plazoEnElCampo);

        assertEquals(0, BigDecimal.ZERO.compareTo(importeGuardado),
                "importeHipoteca debe guardarse en 0 cuando la hipoteca no está activa");
        assertEquals(0, BigDecimal.ZERO.compareTo(cuotaGuardada),
                "cuotaMensualHipoteca debe guardarse en 0 cuando la hipoteca no está activa");
    }

    // ── cuotaMensual() ──────────────────────────────────────────

    @Test
    void cuotaMensual_principalNulo_devuelveCero() {
        assertEquals(0, BigDecimal.ZERO.compareTo(
                CalculadoraFinancieraPiso.cuotaMensual(null, BigDecimal.TEN, 20)));
    }

    @Test
    void cuotaMensual_tasaNula_devuelveCero() {
        assertEquals(0, BigDecimal.ZERO.compareTo(
                CalculadoraFinancieraPiso.cuotaMensual(BigDecimal.valueOf(100000), null, 20)));
    }

    @Test
    void cuotaMensual_plazoCeroONegativo_devuelveCero() {
        assertEquals(0, BigDecimal.ZERO.compareTo(
                CalculadoraFinancieraPiso.cuotaMensual(BigDecimal.valueOf(100000), BigDecimal.TEN, 0)));
        assertEquals(0, BigDecimal.ZERO.compareTo(
                CalculadoraFinancieraPiso.cuotaMensual(BigDecimal.valueOf(100000), BigDecimal.TEN, -5)));
    }

    @Test
    void cuotaMensual_principalCero_devuelveCero() {
        assertEquals(0, BigDecimal.ZERO.compareTo(
                CalculadoraFinancieraPiso.cuotaMensual(BigDecimal.ZERO, BigDecimal.TEN, 20)));
    }

    @Test
    void cuotaMensual_tasaCero_esDivisionLineal() {
        // 120000 a 10 años sin interés = 120000 / 120 meses = 1000.00
        BigDecimal cuota = CalculadoraFinancieraPiso.cuotaMensual(
                BigDecimal.valueOf(120000), BigDecimal.ZERO, 10);
        assertEquals(0, new BigDecimal("1000.00").compareTo(cuota));
    }

    @Test
    void cuotaMensual_amortizacionFrancesa_valorDeReferencia() {
        // 80000 al 3% anual a 20 años -> 443.68 (verificado con Python, no con esta misma fórmula)
        BigDecimal cuota = CalculadoraFinancieraPiso.cuotaMensual(
                new BigDecimal("80000"), new BigDecimal("3.0"), 20);
        assertEquals(0, new BigDecimal("443.68").compareTo(cuota));
    }

    // ── calcular() — escenario completo con hipoteca ─────────────

    private DatosAdquisicion adquisicionA() {
        return new DatosAdquisicion(
                new BigDecimal("100000"), new BigDecimal("8000"), new BigDecimal("1000"),
                new BigDecimal("500"), BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO);
    }

    private DatosGastos gastosA() {
        return new DatosGastos(new BigDecimal("400"), new BigDecimal("60"),
                new BigDecimal("150"), new BigDecimal("300"));
    }

    @Test
    void calcular_escenarioCompletoConHipoteca_coincideConValoresDeReferencia() {
        Entrada entrada = new Entrada(
                adquisicionA(),
                new DatosHipoteca(true, new BigDecimal("80000"), new BigDecimal("3.0"), 20),
                gastosA(),
                new BigDecimal("130000"),
                new BigDecimal("700"));

        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);

        assertEquals(0, new BigDecimal("109500").compareTo(r.inversionTotal()));
        assertEquals(0, new BigDecimal("443.68").compareTo(r.cuotaMensualHipoteca()));
        assertEquals(0, new BigDecimal("1570").compareTo(r.totalGastosAnuales()));
        assertEquals(7.671200, r.rentabilidadBrutaPct(), 0.0001);
        // (8400 - 1570) / 109500 * 100 = 6.2374 — rentNeta NO resta la hipoteca
        // (ver comentario en CalculadoraFinancieraPiso.calcular()).
        assertEquals(6.2374, r.rentabilidadNetaPct(), 0.0001);
        assertEquals(Calificacion.EXCELENTE, r.calificacion());
        assertEquals(0, new BigDecimal("125.49").compareTo(r.cashFlowMensual()));
        assertEquals(5.104700, r.cashOnCashPct(), 0.0001);
        assertEquals(0, new BigDecimal("29500").compareTo(r.capitalPropio()));
        assertEquals(0, new BigDecimal("20500").compareTo(r.plusvaliaLatente()));
        assertEquals(13.04, r.perAnios(), 0.001);
    }

    @Test
    void calcular_sinHipoteca_cuotaCeroYCapitalPropioIgualAInversion() {
        Entrada entrada = new Entrada(
                adquisicionA(),
                new DatosHipoteca(false, new BigDecimal("80000"), new BigDecimal("3.0"), 20), // valores en los campos pero checkbox apagado
                gastosA(),
                new BigDecimal("130000"),
                new BigDecimal("700"));

        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);

        assertEquals(0, BigDecimal.ZERO.compareTo(r.cuotaMensualHipoteca()),
                "Sin hipoteca activa, la cuota debe ser 0 aunque el campo importe tenga valor");
        assertEquals(0, r.inversionTotal().compareTo(r.capitalPropio()),
                "Sin hipoteca activa, el capital propio debe ser igual a la inversión total");
    }

    @Test
    void calcular_inversionTotalCero_rentabilidadYCalificacionNoCalculables() {
        DatosAdquisicion sinCoste = new DatosAdquisicion(
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO);
        Entrada entrada = new Entrada(
                sinCoste,
                new DatosHipoteca(false, BigDecimal.ZERO, BigDecimal.ZERO, 0),
                gastosA(),
                new BigDecimal("50000"),
                new BigDecimal("700"));

        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);

        assertNull(r.rentabilidadBrutaPct(), "inversionTotal <= 0 -> no calculable, debe ser null (el controller no toca el Label)");
        assertNull(r.rentabilidadNetaPct());
        assertNull(r.calificacion());
        // Cash flow, capital propio y plusvalía SÍ se calculan siempre, sin guarda:
        assertNotNull(r.cashFlowMensual());
        assertNotNull(r.capitalPropio());
        assertNotNull(r.plusvaliaLatente());
    }

    @Test
    void calcular_capitalPropioNoPositivo_cashOnCashNoCalculable() {
        // Hipoteca por más del total de la inversión -> capital propio <= 0
        Entrada entrada = new Entrada(
                adquisicionA(), // inversión total 109500
                new DatosHipoteca(true, new BigDecimal("120000"), new BigDecimal("3.0"), 20),
                gastosA(),
                new BigDecimal("130000"),
                new BigDecimal("700"));

        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);

        assertTrue(r.capitalPropio().compareTo(BigDecimal.ZERO) <= 0);
        assertNull(r.cashOnCashPct(), "capitalPropio <= 0 -> cash-on-cash no calculable, debe ser null");
    }

    @Test
    void calcular_ingresosMesCero_perNoCalculablePeroRentabilidadSiguesiendoUnValorReal() {
        Entrada entrada = new Entrada(
                adquisicionA(),
                new DatosHipoteca(false, BigDecimal.ZERO, BigDecimal.ZERO, 0),
                gastosA(),
                new BigDecimal("130000"),
                BigDecimal.ZERO);

        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);

        assertNull(r.perAnios(), "ingresos anuales 0 -> PER no calculable, debe ser null");
        assertNotNull(r.rentabilidadBrutaPct(), "inversionTotal > 0, rentabilidad SÍ es calculable (será 0.0, no null)");
        assertEquals(0.0, r.rentabilidadBrutaPct(), 0.0001);
    }

    // ── Umbrales de calificación (calcular() los recorre con distintos ingresos) ──

    private double rentBrutaPara(BigDecimal ingresosMes) {
        Entrada entrada = new Entrada(
                new DatosAdquisicion(new BigDecimal("100000"), BigDecimal.ZERO, BigDecimal.ZERO,
                        BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO),
                new DatosHipoteca(false, BigDecimal.ZERO, BigDecimal.ZERO, 0),
                new DatosGastos(BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO),
                BigDecimal.ZERO,
                ingresosMes);
        return CalculadoraFinancieraPiso.calcular(entrada).rentabilidadBrutaPct();
    }

    @Test
    void calificacion_rentaBrutaMayorA7_esExcelente() {
        // ingresos anuales / 100000 * 100 > 7 -> ingresos anuales > 7000 -> ingresosMes > 583.33
        Entrada entrada = new Entrada(
                new DatosAdquisicion(new BigDecimal("100000"), BigDecimal.ZERO, BigDecimal.ZERO,
                        BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO),
                new DatosHipoteca(false, BigDecimal.ZERO, BigDecimal.ZERO, 0),
                new DatosGastos(BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO),
                BigDecimal.ZERO,
                new BigDecimal("600")); // 7200/año -> 7.2%
        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);
        assertEquals(Calificacion.EXCELENTE, r.calificacion());
    }

    @Test
    void calificacion_rentaBrutaExactamente7_esAceptableNoExcelente() {
        // 100000 inversión, ingresosMes tal que rentBruta == 7.0 exacto: ingresos anuales = 7000 -> mes = 583.3333...
        Entrada entrada = new Entrada(
                new DatosAdquisicion(new BigDecimal("100000"), BigDecimal.ZERO, BigDecimal.ZERO,
                        BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO),
                new DatosHipoteca(false, BigDecimal.ZERO, BigDecimal.ZERO, 0),
                new DatosGastos(BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO),
                BigDecimal.ZERO,
                new BigDecimal("583.333333"));
        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);
        assertEquals(7.0, r.rentabilidadBrutaPct(), 0.001);
        assertEquals(Calificacion.ACEPTABLE, r.calificacion(), "el umbral EXCELENTE es '> 7', no '>= 7'");
    }

    @Test
    void calificacion_rentaBrutaExactamente5_esAceptable() {
        Entrada entrada = new Entrada(
                new DatosAdquisicion(new BigDecimal("100000"), BigDecimal.ZERO, BigDecimal.ZERO,
                        BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO),
                new DatosHipoteca(false, BigDecimal.ZERO, BigDecimal.ZERO, 0),
                new DatosGastos(BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO),
                BigDecimal.ZERO,
                new BigDecimal("416.666667")); // 5000/año -> 5.0%
        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);
        assertEquals(5.0, r.rentabilidadBrutaPct(), 0.001);
        assertEquals(Calificacion.ACEPTABLE, r.calificacion());
    }

    @Test
    void calificacion_rentaBrutaMenorA5_esARevisar() {
        Entrada entrada = new Entrada(
                new DatosAdquisicion(new BigDecimal("100000"), BigDecimal.ZERO, BigDecimal.ZERO,
                        BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO),
                new DatosHipoteca(false, BigDecimal.ZERO, BigDecimal.ZERO, 0),
                new DatosGastos(BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO),
                BigDecimal.ZERO,
                new BigDecimal("400")); // 4800/año -> 4.8%
        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);
        assertEquals(Calificacion.A_REVISAR, r.calificacion());
    }

    // ── DatosAdquisicion.total() / DatosGastos.totalAnual() ──────

    @Test
    void datosAdquisicion_total_sumaTodosLosCampos() {
        assertEquals(0, new BigDecimal("109500").compareTo(adquisicionA().total()));
    }

    @Test
    void datosGastos_totalAnual_multiplicaComunidadPorDoce() {
        // 400 + 60*12 + 150 + 300 = 1570
        assertEquals(0, new BigDecimal("1570").compareTo(gastosA().totalAnual()));
    }

    // ── Fase 0 paso 3: casos que se usaron para comparar contra la
    // implementación duplicada de RentabilidadController antes de unificarlas
    // (EquivalenciaRentabilidadTest, temporal, ya eliminado). Confirmaron
    // equivalencia total salvo en rentabilidadNetaPct, que aquí restaba la
    // cuota de hipoteca y en RentabilidadController no — se corrigió este
    // método para NO restarla (ver comentario en calcular()). Se conservan
    // estos escenarios como cobertura permanente. ──────────────────────

    @Test
    void calcular_valoresTipicosConHipoteca() {
        var adquisicion = new DatosAdquisicion(
                BigDecimal.valueOf(200_000), BigDecimal.valueOf(12_000),
                BigDecimal.valueOf(1500), BigDecimal.ZERO,
                BigDecimal.ZERO, BigDecimal.valueOf(5000), BigDecimal.valueOf(3800));
        var hipoteca = new DatosHipoteca(true, BigDecimal.valueOf(160_000), BigDecimal.valueOf(3.5), 25);
        var gastos = new DatosGastos(
                BigDecimal.valueOf(1200), BigDecimal.valueOf(80), BigDecimal.valueOf(480), BigDecimal.valueOf(360));
        Entrada entrada = new Entrada(adquisicion, hipoteca, gastos, BigDecimal.ZERO, BigDecimal.valueOf(900));

        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);

        assertEquals(0, new BigDecimal("222300").compareTo(r.inversionTotal()));
        assertEquals(801.00, r.cuotaMensualHipoteca().doubleValue(), 0.01);
        assertEquals(4.8583, r.rentabilidadBrutaPct(), 0.001);
        assertEquals(3.5088, r.rentabilidadNetaPct(), 0.001, "no debe restar la cuota de hipoteca");
        assertEquals(-151.00, r.cashFlowMensual().doubleValue(), 0.01);
    }

    @Test
    void calcular_hipotecaDesactivada_rentNetaCoincideConRentBrutaMenosGastos() {
        var adquisicion = new DatosAdquisicion(
                BigDecimal.valueOf(150_000), BigDecimal.valueOf(12_000),
                BigDecimal.valueOf(1200), BigDecimal.ZERO,
                BigDecimal.valueOf(2000), BigDecimal.ZERO, BigDecimal.ZERO);
        var hipoteca = new DatosHipoteca(false, BigDecimal.ZERO, BigDecimal.valueOf(3.0), 20);
        var gastos = new DatosGastos(
                BigDecimal.valueOf(720), BigDecimal.valueOf(50), BigDecimal.valueOf(240), BigDecimal.valueOf(720));
        Entrada entrada = new Entrada(adquisicion, hipoteca, gastos, BigDecimal.ZERO, BigDecimal.valueOf(700));

        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);

        assertEquals(0, new BigDecimal("165200").compareTo(r.inversionTotal()));
        assertEquals(0, BigDecimal.ZERO.compareTo(r.cuotaMensualHipoteca()));
        assertEquals(5.0847, r.rentabilidadBrutaPct(), 0.001);
        assertEquals(3.7046, r.rentabilidadNetaPct(), 0.001);
        assertEquals(510.00, r.cashFlowMensual().doubleValue(), 0.01);
    }

    @Test
    void calcular_plazoExtremoUnAnio_cuotaAltaYCashFlowNegativo() {
        var adquisicion = new DatosAdquisicion(
                BigDecimal.valueOf(120_000), BigDecimal.valueOf(12_000),
                BigDecimal.valueOf(1000), BigDecimal.ZERO,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.valueOf(2000));
        var hipoteca = new DatosHipoteca(true, BigDecimal.valueOf(72_000), BigDecimal.valueOf(4.0), 1);
        var gastos = new DatosGastos(
                BigDecimal.valueOf(600), BigDecimal.valueOf(60), BigDecimal.valueOf(240), BigDecimal.valueOf(240));
        Entrada entrada = new Entrada(adquisicion, hipoteca, gastos, BigDecimal.ZERO, BigDecimal.valueOf(650));

        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);

        assertEquals(0, new BigDecimal("135000").compareTo(r.inversionTotal()));
        assertEquals(6130.79, r.cuotaMensualHipoteca().doubleValue(), 0.01);
        assertEquals(4.4444, r.rentabilidadNetaPct(), 0.001);
        assertEquals(-5630.79, r.cashFlowMensual().doubleValue(), 0.01);
    }

    @Test
    void calcular_plazoExtremoCuarentaAnios_cuotaBaja() {
        var adquisicion = new DatosAdquisicion(
                BigDecimal.valueOf(300_000), BigDecimal.valueOf(30_000),
                BigDecimal.valueOf(2000), BigDecimal.ZERO,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.valueOf(5000));
        var hipoteca = new DatosHipoteca(true, BigDecimal.valueOf(270_000), BigDecimal.valueOf(3.2), 40);
        var gastos = new DatosGastos(
                BigDecimal.valueOf(1440), BigDecimal.valueOf(100), BigDecimal.valueOf(600), BigDecimal.valueOf(600));
        Entrada entrada = new Entrada(adquisicion, hipoteca, gastos, BigDecimal.ZERO, BigDecimal.valueOf(1100));

        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);

        assertEquals(0, new BigDecimal("337000").compareTo(r.inversionTotal()));
        assertEquals(997.94, r.cuotaMensualHipoteca().doubleValue(), 0.01);
        assertEquals(2.7774, r.rentabilidadNetaPct(), 0.001);
    }

    @Test
    void calcular_interesCero_cuotaEsDivisionLinealYRentNetaCorrecta() {
        var adquisicion = new DatosAdquisicion(
                BigDecimal.valueOf(180_000), BigDecimal.valueOf(10_800),
                BigDecimal.valueOf(1500), BigDecimal.ZERO,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.valueOf(3200));
        var hipoteca = new DatosHipoteca(true, BigDecimal.valueOf(126_000), BigDecimal.ZERO, 15);
        var gastos = new DatosGastos(
                BigDecimal.valueOf(960), BigDecimal.valueOf(70), BigDecimal.valueOf(360), BigDecimal.valueOf(360));
        Entrada entrada = new Entrada(adquisicion, hipoteca, gastos, BigDecimal.ZERO, BigDecimal.valueOf(800));

        Resultado r = CalculadoraFinancieraPiso.calcular(entrada);

        assertEquals(700.00, r.cuotaMensualHipoteca().doubleValue(), 0.01, "126000/180 meses = 700.00");
        assertEquals(3.6215, r.rentabilidadNetaPct(), 0.001);
    }

    /** Mismo escenario base con distinto ITP (Madrid/Cataluña/País Vasco) — sin hipoteca, para aislar el efecto del ITP. */
    private Resultado calcularConItp(BigDecimal itpPagado) {
        var adquisicion = new DatosAdquisicion(
                BigDecimal.valueOf(250_000), itpPagado,
                BigDecimal.valueOf(1800), BigDecimal.ZERO,
                BigDecimal.ZERO, BigDecimal.valueOf(2000), BigDecimal.valueOf(3500));
        var hipoteca = new DatosHipoteca(false, BigDecimal.ZERO, BigDecimal.valueOf(3.0), 20);
        var gastos = new DatosGastos(
                BigDecimal.valueOf(1080), BigDecimal.valueOf(90), BigDecimal.valueOf(420), BigDecimal.valueOf(600));
        Entrada entrada = new Entrada(adquisicion, hipoteca, gastos, BigDecimal.ZERO, BigDecimal.valueOf(1000));
        return CalculadoraFinancieraPiso.calcular(entrada);
    }

    @Test
    void calcular_itpMadrid_seisPorCiento() {
        Resultado r = calcularConItp(BigDecimal.valueOf(15_000)); // 250000 * 6%
        assertEquals(0, new BigDecimal("272300").compareTo(r.inversionTotal()));
        assertEquals(4.4069, r.rentabilidadBrutaPct(), 0.001);
        assertEquals(3.2391, r.rentabilidadNetaPct(), 0.001);
    }

    @Test
    void calcular_itpCataluna_diezPorCiento() {
        Resultado r = calcularConItp(BigDecimal.valueOf(25_000)); // 250000 * 10%
        assertEquals(0, new BigDecimal("282300").compareTo(r.inversionTotal()));
        assertEquals(4.2508, r.rentabilidadBrutaPct(), 0.001);
        assertEquals(3.1243, r.rentabilidadNetaPct(), 0.001);
    }

    @Test
    void calcular_itpPaisVasco_cuatroPorCiento() {
        Resultado r = calcularConItp(BigDecimal.valueOf(10_000)); // 250000 * 4%
        assertEquals(0, new BigDecimal("267300").compareTo(r.inversionTotal()));
        assertEquals(4.4893, r.rentabilidadBrutaPct(), 0.001);
        assertEquals(3.2997, r.rentabilidadNetaPct(), 0.001);
    }
}
