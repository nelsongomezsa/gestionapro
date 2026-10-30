package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;
import java.util.List;

/** Cobros de un mes: lo esperado por los contratos vigentes, lo cobrado y lo pendiente. */
public record ResumenPagosResponse(
        @Schema(example = "2026-10") String mes,
        @Schema(example = "octubre 2026") String nombreMes,
        @Schema(description = "Suma de rentas de los contratos vigentes en algún momento del mes") BigDecimal esperado,
        @Schema(description = "Suma de los pagos registrados en el mes") BigDecimal cobrado,
        @Schema(description = "Suma de rentas de los contratos vigentes sin ningún pago en el mes") BigDecimal pendiente,
        int numeroPagos,
        @Schema(description = "Contratos sin pago en el mes (mismo criterio que el aviso del escritorio)")
        List<Pendiente> pendientes) {

    public record Pendiente(Integer idContrato, ContratoResponse.InquilinoBreve inquilino, int numeroHabitacion,
                            PisoBreve piso, BigDecimal importe) {}
}
