package com.gestionap.api.web.dto;

import com.gestionap.api.domain.Fianza;

import java.math.BigDecimal;
import java.time.LocalDate;

public record FianzaResponse(
        Integer id,
        Integer idContrato,
        String inquilino,
        int numeroHabitacion,
        PisoBreve piso,
        BigDecimal importe,
        LocalDate fechaCobro,
        LocalDate fechaDeposito,
        String organismoDeposito,
        String referenciaDeposito,
        LocalDate fechaDevolucion,
        BigDecimal importeDevuelto,
        String motivoRetencion,
        String notas,
        Estado estado,
        /** Lo que aún se debe devolver: el importe entero mientras no se registre la devolución. */
        BigDecimal pendienteDevolver,
        /** Lo que se quedó el propietario al devolverla (con su motivo). */
        BigDecimal retenido) {

    public enum Estado { SIN_DEPOSITAR, DEPOSITADA, DEVUELTA, DEVUELTA_PARCIAL }

    public static FianzaResponse de(Fianza f) {
        var c = f.getContrato();
        BigDecimal retenido = f.devuelta() ? f.getImporte().subtract(f.getImporteDevuelto()) : BigDecimal.ZERO;
        Estado estado = f.devuelta()
                ? (retenido.signum() == 0 ? Estado.DEVUELTA : Estado.DEVUELTA_PARCIAL)
                : (f.getFechaDeposito() != null ? Estado.DEPOSITADA : Estado.SIN_DEPOSITAR);
        return new FianzaResponse(f.getId(), c.getId(), c.getInquilino().getNombreCompleto(),
                c.getHabitacion().getNumero(), PisoBreve.de(c.getHabitacion().getPiso()),
                f.getImporte(), f.getFechaCobro(), f.getFechaDeposito(), f.getOrganismoDeposito(),
                f.getReferenciaDeposito(), f.getFechaDevolucion(), f.getImporteDevuelto(), f.getMotivoRetencion(),
                f.getNotas(), estado, f.devuelta() ? BigDecimal.ZERO : f.getImporte(), retenido);
    }
}
