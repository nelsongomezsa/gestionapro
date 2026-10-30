package com.gestionap.api.web.dto;

import com.gestionap.api.domain.MetodoPago;
import com.gestionap.api.domain.Pago;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PagoResponse(
        Integer id,
        LocalDate fechaPago,
        BigDecimal cantidad,
        MetodoPago metodoPago,
        Integer idContrato,
        ContratoResponse.InquilinoBreve inquilino,
        int numeroHabitacion,
        PisoBreve piso,
        /** 2026-0007, o null si aún no se ha emitido su recibo. */
        String recibo) {

    public static PagoResponse de(Pago p) {
        return de(p, null);
    }

    public static PagoResponse de(Pago p, String recibo) {
        var c = p.getContrato();
        var i = c.getInquilino();
        return new PagoResponse(p.getId(), p.getFechaPago(), p.getCantidad(), p.getMetodoPago(), c.getId(),
                new ContratoResponse.InquilinoBreve(i.getId(), i.getNombreCompleto(), i.getDni(), i.getTelefono(), i.getEmail()),
                c.getHabitacion().getNumero(), PisoBreve.de(c.getHabitacion().getPiso()), recibo);
    }
}
