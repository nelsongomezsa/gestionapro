package com.gestionap.api.web.dto;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.NivelVencimiento;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

public record ContratoResponse(
        Integer id,
        HabitacionBreve habitacion,
        PisoBreve piso,
        InquilinoBreve inquilino,
        LocalDate fechaInicio,
        LocalDate fechaFin,
        BigDecimal precioMensual,
        @Schema(description = "Vigente hoy") boolean activo,
        @Schema(description = "Crítico: vence en 7 días o menos; próximo: en 30 o menos") NivelVencimiento vencimiento,
        @Schema(description = "Días hasta la fecha de fin (negativo si ya pasó)") long diasRestantes) {

    public record HabitacionBreve(Integer id, int numero) {}

    public record InquilinoBreve(Integer id, String nombre, String dni, String telefono, String email) {}

    public static ContratoResponse de(Contrato c, LocalDate hoy) {
        var i = c.getInquilino();
        return new ContratoResponse(c.getId(),
                new HabitacionBreve(c.getHabitacion().getId(), c.getHabitacion().getNumero()),
                PisoBreve.de(c.getHabitacion().getPiso()),
                new InquilinoBreve(i.getId(), i.getNombreCompleto(), i.getDni(), i.getTelefono(), i.getEmail()),
                c.getFechaInicio(), c.getFechaFin(), c.getPrecioMensual(), c.estaActivoEn(hoy),
                NivelVencimiento.de(c.getFechaFin(), hoy), ChronoUnit.DAYS.between(hoy, c.getFechaFin()));
    }
}
