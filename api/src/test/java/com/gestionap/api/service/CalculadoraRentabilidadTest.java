package com.gestionap.api.service;

import com.gestionap.api.config.ItpRatesTest;
import com.gestionap.api.service.CalculadoraRentabilidad.Entrada;
import com.gestionap.api.service.CalculadoraRentabilidad.Resultado;
import com.gestionap.api.web.ApiException;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Valores esperados obtenidos ejecutando el RentabilidadController REAL de la
 * app de escritorio (commit 0b39841) sin ventana: se rellenaron sus TextField
 * con estas entradas y se leyeron sus campos internos (_rentBruta,
 * _cashFlowMensual...). Se comparan con delta 0: las operaciones son las
 * mismas y en el mismo orden, así que el double debe ser idéntico.
 *
 * <p>Donde el escritorio guarda -1 o 0 y muestra "—" (años para recuperar,
 * plusvalías sin revalorización), la API devuelve null.
 */
class CalculadoraRentabilidadTest {

    private static CalculadoraRentabilidad calculadora;

    @BeforeAll
    static void cargarItp() throws Exception {
        calculadora = new CalculadoraRentabilidad(ItpRatesTest.cargar());
    }

    private static Entrada entrada(String comunidad, double... v) {
        return new Entrada(comunidad, v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10],
                v[11], v[12], v[13], (int) v[14], v[15]);
    }

    @Test
    void madrid_conHipotecaYRevalorizacion() {
        Resultado r = calculadora.calcular(entrada("Madrid",
                200000, 2500, 1500, 10000, 3000, 4000, 50, 30, 80, 40, 60, 1400, 3, 80, 25, 3.2));

        assertThat(r.itpPct()).isEqualTo(6.0);
        assertThat(r.itpImporte()).isEqualTo(12000.0);
        assertThat(r.totalCompra()).isEqualTo(233000.0);
        assertThat(r.gastosMensuales()).isEqualTo(260.0);
        assertThat(r.gastosAnuales()).isEqualTo(3120.0);
        assertThat(r.alquilerAnual()).isEqualTo(16800.0);
        assertThat(r.hipoteca()).isEqualTo(160000.0);
        assertThat(r.capitalAportado()).isEqualTo(73000.0);
        assertThat(r.cuotaMensual()).isEqualTo(775.49);
        assertThat(r.interesesMensualesPromedio()).isEqualTo(242.15666666666667);
        assertThat(r.amortizacionMensualPromedio()).isEqualTo(533.3333333333334);
        assertThat(r.rentabilidadBrutaPct()).isEqualTo(7.2103);
        assertThat(r.rentabilidadNetaPct()).isEqualTo(5.8712);
        assertThat(r.cashFlowMensual()).isEqualTo(364.51);
        assertThat(r.cashFlowAnual()).isEqualTo(4374.12);
        assertThat(r.aniosRecuperacion()).isEqualTo(16.68907117317312);
        assertThat(r.plusvalia5Anios()).isEqualTo(31854.814860000013);
        assertThat(r.plusvalia10Anios()).isEqualTo(68783.27586882445);
    }

    @Test
    void cataluna_alContadoSinRevalorizacion() {
        Resultado r = calculadora.calcular(entrada("Cataluña",
                180000, 2000, 0, 5000, 0, 3000, 45, 25, 70, 30, 50, 1100, 0, 0, 0, 0));

        assertThat(r.itpPct()).isEqualTo(10.0);
        assertThat(r.itpImporte()).isEqualTo(18000.0);
        assertThat(r.totalCompra()).isEqualTo(208000.0);
        assertThat(r.gastosMensuales()).isEqualTo(220.0);
        assertThat(r.gastosAnuales()).isEqualTo(2640.0);
        assertThat(r.hipoteca()).isEqualTo(0.0);
        assertThat(r.capitalAportado()).isEqualTo(208000.0);
        assertThat(r.cuotaMensual()).isEqualTo(0.0);
        assertThat(r.interesesMensualesPromedio()).isEqualTo(0.0);
        assertThat(r.amortizacionMensualPromedio()).isEqualTo(0.0);
        assertThat(r.rentabilidadBrutaPct()).isEqualTo(6.3462);
        assertThat(r.rentabilidadNetaPct()).isEqualTo(5.0769);
        assertThat(r.cashFlowMensual()).isEqualTo(880.0);
        assertThat(r.cashFlowAnual()).isEqualTo(10560.0);
        assertThat(r.aniosRecuperacion()).isEqualTo(19.696969696969695);
        assertThat(r.plusvalia5Anios()).as("escritorio: 0 y '—'").isNull();
        assertThat(r.plusvalia10Anios()).isNull();
    }

    @Test
    void paisVasco_interesCero_conservaElResiduoDeRedondeoDelEscritorio() {
        Resultado r = calculadora.calcular(entrada("País Vasco",
                220000, 2200, 1200, 0, 2500, 2000, 55, 35, 90, 40, 70, 1300, 2, 70, 20, 0));

        assertThat(r.itpPct()).isEqualTo(4.0);
        assertThat(r.itpImporte()).isEqualTo(8800.0);
        assertThat(r.totalCompra()).isEqualTo(236700.0);
        assertThat(r.hipoteca()).isEqualTo(154000.0);
        assertThat(r.capitalAportado()).isEqualTo(82700.0);
        assertThat(r.cuotaMensual()).isEqualTo(641.67);
        // La cuota viene redondeada a céntimos, así que "intereses" al 0 % no es exactamente 0.
        assertThat(r.interesesMensualesPromedio()).isEqualTo(0.0033333333332848268);
        assertThat(r.amortizacionMensualPromedio()).isEqualTo(641.6666666666666);
        assertThat(r.rentabilidadBrutaPct()).isEqualTo(6.5906);
        assertThat(r.rentabilidadNetaPct()).isEqualTo(5.1204);
        assertThat(r.cashFlowMensual()).isEqualTo(368.33);
        assertThat(r.cashFlowAnual()).isEqualTo(4419.96);
        assertThat(r.aniosRecuperacion()).isEqualTo(18.710576566303768);
        assertThat(r.plusvalia5Anios()).isEqualTo(22897.776704000004);
        assertThat(r.plusvalia10Anios()).isEqualTo(48178.77239884661);
    }

    @Test
    void canarias_plazoCorto_cashFlowNegativoSinAniosDeRecuperacion() {
        Resultado r = calculadora.calcular(entrada("Canarias",
                120000, 1500, 900, 2000, 1500, 1500, 30, 20, 50, 25, 40, 700, 1.5, 90, 5, 4.1));

        assertThat(r.itpPct()).isEqualTo(6.5);
        assertThat(r.itpImporte()).isEqualTo(7800.0);
        assertThat(r.totalCompra()).isEqualTo(135200.0);
        assertThat(r.gastosMensuales()).isEqualTo(165.0);
        assertThat(r.gastosAnuales()).isEqualTo(1980.0);
        assertThat(r.hipoteca()).isEqualTo(108000.0);
        assertThat(r.capitalAportado()).isEqualTo(27200.0);
        assertThat(r.cuotaMensual()).isEqualTo(1993.86);
        assertThat(r.interesesMensualesPromedio()).isEqualTo(193.85999999999984);
        assertThat(r.amortizacionMensualPromedio()).isEqualTo(1800.0);
        assertThat(r.rentabilidadBrutaPct()).isEqualTo(6.213);
        assertThat(r.rentabilidadNetaPct()).isEqualTo(4.7485);
        assertThat(r.cashFlowMensual()).isEqualTo(-1458.86);
        assertThat(r.cashFlowAnual()).isEqualTo(-17506.32);
        assertThat(r.aniosRecuperacion()).as("escritorio: -1 y '—'").isNull();
        assertThat(r.plusvalia5Anios()).isEqualTo(9274.08046612494);
        assertThat(r.plusvalia10Anios()).isEqualTo(19264.89900301788);
    }

    @Test
    void todoACero_rentabilidadesACeroComoEnEscritorio() {
        Resultado r = calculadora.calcular(entrada("Andalucía",
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));

        assertThat(r.itpPct()).isEqualTo(7.0);
        assertThat(r.itpImporte()).isEqualTo(0.0);
        assertThat(r.totalCompra()).isEqualTo(0.0);
        assertThat(r.rentabilidadBrutaPct()).isEqualTo(0.0);
        assertThat(r.rentabilidadNetaPct()).isEqualTo(0.0);
        assertThat(r.cashFlowMensual()).isEqualTo(0.0);
        assertThat(r.aniosRecuperacion()).isNull();
        assertThat(r.plusvalia5Anios()).isNull();
    }

    @Test
    void cantabria_sinAlquiler_rentabilidadNetaNegativa() {
        Resultado r = calculadora.calcular(entrada("Cantabria",
                95000, 1200, 800, 15000, 2000, 3500, 25, 15, 40, 30, 35, 0, 4.5, 60, 30, 2.75));

        assertThat(r.itpPct()).isEqualTo(10.0);
        assertThat(r.itpImporte()).isEqualTo(9500.0);
        assertThat(r.totalCompra()).isEqualTo(127000.0);
        assertThat(r.gastosMensuales()).isEqualTo(145.0);
        assertThat(r.gastosAnuales()).isEqualTo(1740.0);
        assertThat(r.hipoteca()).isEqualTo(57000.0);
        assertThat(r.capitalAportado()).isEqualTo(70000.0);
        assertThat(r.cuotaMensual()).isEqualTo(232.7);
        assertThat(r.interesesMensualesPromedio()).isEqualTo(74.36666666666666);
        assertThat(r.amortizacionMensualPromedio()).isEqualTo(158.33333333333331);
        assertThat(r.rentabilidadBrutaPct()).isEqualTo(0.0);
        assertThat(r.rentabilidadNetaPct()).isEqualTo(-1.3701);
        assertThat(r.cashFlowMensual()).isEqualTo(-377.7);
        assertThat(r.cashFlowAnual()).isEqualTo(-4532.4);
        assertThat(r.aniosRecuperacion()).isNull();
        assertThat(r.plusvalia5Anios()).isEqualTo(23387.284077046825);
        assertThat(r.plusvalia10Anios()).isEqualTo(52532.09506462514);
    }

    @Test
    void comunidadDesconocida_es400() {
        assertThatThrownBy(() -> calculadora.calcular(entrada("Atlantis",
                100000, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 500, 0, 0, 0, 0)))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("Atlantis");
    }
}
