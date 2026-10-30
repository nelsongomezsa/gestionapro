package com.gestionap.api.web.dto;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.NivelVencimiento;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ContratoBreve(
        Integer id,
        Integer idHabitacion,
        int numeroHabitacion,
        PisoBreve piso,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        BigDecimal precioMensual,
        boolean activo,
        NivelVencimiento vencimiento) {

    public static ContratoBreve de(Contrato c, LocalDate hoy) {
        return new ContratoBreve(c.getId(), c.getHabitacion().getId(), c.getHabitacion().getNumero(),
                PisoBreve.de(c.getHabitacion().getPiso()), c.getFechaInicio(), c.getFechaFin(), c.getPrecioMensual(),
                c.estaActivoEn(hoy), NivelVencimiento.de(c.getFechaFin(), hoy));
    }
}
