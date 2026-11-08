package com.gestionap.api.service;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * Desglose del IVA de una renta (V12). La renta guardada es lo que paga el inquilino, IVA incluido:
 * base = total / (1 + %/100), redondeada al céntimo; cuota = total − base (así base + cuota = total exacto).
 */
public final class Iva {

    /** Tipo general en España; el propietario puede cambiarlo en cada contrato. */
    public static final BigDecimal GENERAL = new BigDecimal("21.00");
    public static final BigDecimal MAXIMO = new BigDecimal("30.00");

    public record Desglose(BigDecimal base, BigDecimal pct, BigDecimal cuota, BigDecimal total) {}

    private Iva() {}

    public static Desglose desglosar(BigDecimal total, BigDecimal pct) {
        BigDecimal divisor = BigDecimal.ONE.add(pct.movePointLeft(2));
        BigDecimal base = total.divide(divisor, 2, RoundingMode.HALF_UP);
        return new Desglose(base, pct.setScale(2, RoundingMode.HALF_UP), total.subtract(base), total);
    }
}
