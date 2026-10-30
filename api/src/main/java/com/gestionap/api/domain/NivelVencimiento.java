package com.gestionap.api.domain;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

/**
 * Nivel de vencimiento de un contrato. Mismos umbrales que VencimientoContrato del
 * escritorio: crítico si quedan 7 días o menos, próximo si quedan 30 o menos.
 */
public enum NivelVencimiento {
    VENCIDO, CRITICO, PROXIMO, NORMAL;

    public static final int UMBRAL_CRITICO_DIAS = 7;
    public static final int UMBRAL_PROXIMO_DIAS = 30;

    public static NivelVencimiento de(LocalDate fechaFin, LocalDate hoy) {
        long dias = ChronoUnit.DAYS.between(hoy, fechaFin);
        if (dias < 0) return VENCIDO;
        if (dias <= UMBRAL_CRITICO_DIAS) return CRITICO;
        if (dias <= UMBRAL_PROXIMO_DIAS) return PROXIMO;
        return NORMAL;
    }
}
