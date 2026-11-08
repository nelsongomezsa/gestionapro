package com.gestionap.api.web.dto;

import com.gestionap.api.domain.EstadoHabitacion;
import com.gestionap.api.domain.TipoUnidad;
import com.gestionap.api.domain.Vehiculo;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public record HabitacionRequest(
        @NotNull Integer idPiso,
        @NotNull @Min(1) @Max(999) Integer numero,
        @NotNull @DecimalMin(value = "0.01", message = "debe ser mayor que 0") @DecimalMax("99999.99")
        @Digits(integer = 6, fraction = 2) BigDecimal precio,
        @Schema(description = "Opcional; por defecto disponible") EstadoHabitacion estado,
        @Schema(description = "Opcional: por defecto, la unidad propia del inmueble (habitación, plaza o trastero)")
        TipoUnidad tipo,
        @Schema(description = "m², opcional") @DecimalMin("0.5") @DecimalMax("9999.99") @Digits(integer = 4, fraction = 2)
        BigDecimal metros,
        @Schema(description = "Opcional, p. ej. -1") @Size(max = 20) @Pattern(regexp = PATRON_PLANTA) String planta,
        @Schema(description = "Solo plazas de garaje: coche o moto") Vehiculo vehiculo) {

    /** Planta: letras, números, espacios, signo menos, punto y º/ª ("-1", "Sótano 2", "2ª"). */
    public static final String PATRON_PLANTA = "^[\\p{L}\\p{N} .ºª-]*$";

    public HabitacionRequest(Integer idPiso, Integer numero, BigDecimal precio, EstadoHabitacion estado) {
        this(idPiso, numero, precio, estado, null, null, null, null);
    }
}
