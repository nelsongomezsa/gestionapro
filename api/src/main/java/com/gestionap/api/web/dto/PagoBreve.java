package com.gestionap.api.web.dto;

import com.gestionap.api.domain.MetodoPago;
import com.gestionap.api.domain.Pago;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PagoBreve(Integer id, Integer idContrato, LocalDate fechaPago, BigDecimal cantidad, MetodoPago metodoPago) {

    public static PagoBreve de(Pago p) {
        return new PagoBreve(p.getId(), p.getContrato().getId(), p.getFechaPago(), p.getCantidad(), p.getMetodoPago());
    }
}
