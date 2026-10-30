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
        PisoBreve piso) {

    public static PagoResponse de(Pago p) {
        var c = p.getContrato();
        var i = c.getInquilino();
        return new PagoResponse(p.getId(), p.getFechaPago(), p.getCantidad(), p.getMetodoPago(), c.getId(),
                new ContratoResponse.InquilinoBreve(i.getId(), i.getNombreCompleto(), i.getDni(), i.getTelefono(), i.getEmail()),
                c.getHabitacion().getNumero(), PisoBreve.de(c.getHabitacion().getPiso()));
    }
}
