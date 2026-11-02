package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;

/** Un mes anterior al actual en el que un contrato vigente no tuvo ningún pago. */
public record CobroAtrasadoResponse(
        Integer idContrato,
        ContratoResponse.InquilinoBreve inquilino,
        int numeroHabitacion,
        PisoBreve piso,
        @Schema(example = "2026-09") String mes,
        @Schema(example = "septiembre 2026") String nombreMes,
        BigDecimal importe,
        @Schema(description = "Días desde el día 5 del mes adeudado (fin del plazo habitual de pago)") long diasRetraso,
        @Schema(description = "false si el contrato ya terminó: el pago no se puede registrar desde la app") boolean contratoActivo) {}
