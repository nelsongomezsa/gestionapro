package com.gestionap.api.web.dto;

import com.gestionap.api.domain.ActualizacionRenta;
import com.gestionap.api.domain.ActualizacionRenta.Indice;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

public final class ActualizacionRentaDtos {

    private ActualizacionRentaDtos() {}

    /**
     * Lo que tocaría aplicar en el próximo aniversario. porcentaje es el máximo aplicable (el índice
     * elegido, sin pasar del IRAV); porcentaje y rentaNueva son null si no hay dato del INE.
     * fechaEfecto es null si el contrato termina antes del próximo aniversario.
     */
    public record Propuesta(
            boolean debida,
            LocalDate fechaEfecto,
            Indice indice,
            Indice indiceRecomendado,
            String periodoIndice,
            BigDecimal porcentaje,
            /** true si el índice elegido superaba el IRAV y se ha limitado a él. */
            boolean limitadoPorIrav,
            BigDecimal rentaActual,
            BigDecimal rentaNueva,
            String fuente,
            String motivoIndice,
            String aviso) {}

    public record Confirmacion(
            @NotNull LocalDate fechaEfecto,
            @NotNull Indice indice,
            @DecimalMin("-20.0") @DecimalMax("20.0") @Digits(integer = 3, fraction = 3) BigDecimal porcentaje) {}

    public record Historial(
            Integer id,
            LocalDate fechaEfecto,
            Indice indice,
            String periodoIndice,
            BigDecimal porcentaje,
            BigDecimal rentaAnterior,
            BigDecimal rentaNueva,
            String fuente,
            LocalDateTime fechaConfirmacion) {

        public static Historial de(ActualizacionRenta a) {
            return new Historial(a.getId(), a.getFechaEfecto(), a.getIndice(), a.getPeriodoIndice(), a.getPorcentaje(),
                    a.getRentaAnterior(), a.getRentaNueva(), a.getFuente(), a.getFechaConfirmacion());
        }
    }
}
