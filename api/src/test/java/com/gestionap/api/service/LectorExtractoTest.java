package com.gestionap.api.service;

import com.gestionap.api.service.conciliacion.LectorExtracto;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

class LectorExtractoTest {
    private final LectorExtracto lector = new LectorExtracto();

    @Test
    void leeCsvGenericoConSeparadorPuntoYComaEImporteEspanol() {
        var movimientos = lector.leer("Fecha;Concepto;Importe;Saldo\n31/10/2026;Alquiler;1.234,56;2.000,00".getBytes(StandardCharsets.UTF_8));
        assertThat(movimientos).hasSize(1);
        assertThat(movimientos.get(0).importe()).isEqualByComparingTo("1234.56");
        assertThat(movimientos.get(0).saldo()).isEqualByComparingTo("2000.00");
    }

    @Test
    void encuentraCabeceraYColumnasCargoAbono() {
        var movimientos = lector.leer("Extracto de cuenta\nCuenta: 123\nFecha valor;Concepto;Cargo;Abono\n01-10-2026;Ingreso;0,00;45,00".getBytes(StandardCharsets.UTF_8));
        assertThat(movimientos).hasSize(1);
        assertThat(movimientos.get(0).importe()).isEqualByComparingTo("45.00");
    }

    @Test
    void usaIso88591CuandoUtf8NoEsValido() {
        var bytes = "Fecha;Descripción;Importe\n2026-10-31;Pago José;45,00".getBytes(StandardCharsets.ISO_8859_1);
        var movimientos = lector.leer(bytes);
        assertThat(movimientos.get(0).concepto()).contains("José");
    }
}
