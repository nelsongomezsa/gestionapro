package com.gestionap.api.web.dto;

import com.gestionap.api.domain.TipoInmueble;
import com.gestionap.api.domain.TipoUnidad;
import com.gestionap.api.domain.Vehiculo;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

public record PisoRequest(
        @NotBlank @Size(max = 150) String direccion,
        @Schema(description = "Unidades del inmueble: habitaciones (máx. 50 en una vivienda), plazas o trasteros (máx. 500)")
        @NotNull @Min(1) @Max(500) Integer numeroHabitaciones,
        @NotNull Integer idCiudad,
        @Schema(description = "Opcional. En un PUT, si se omite, los datos financieros guardados no cambian")
        @Valid DatosFinancierosDto datosFinancieros,
        @Schema(description = "Solo al crear (se ignora en un PUT): unidades que se crean con el inmueble, "
                + "en la misma operación. Si se envían, tantas como numeroHabitaciones y con números distintos")
        @Valid @Size(max = 500) java.util.List<HabitacionInicial> habitaciones,
        @Schema(description = "Opcional: vivienda (por defecto), garajes o trasteros. En un PUT, si se omite, no cambia")
        TipoInmueble tipo) {

    /** Máximo de habitaciones de una vivienda (el de siempre). */
    public static final int MAX_HABITACIONES_VIVIENDA = 50;

    /** Constructor sin habitaciones ni tipo (edición y código existente). */
    public PisoRequest(String direccion, Integer numeroHabitaciones, Integer idCiudad, DatosFinancierosDto datosFinancieros) {
        this(direccion, numeroHabitaciones, idCiudad, datosFinancieros, null, null);
    }

    public record HabitacionInicial(
            @NotNull @Min(1) @Max(999) Integer numero,
            @NotNull @DecimalMin(value = "0.01", message = "debe ser mayor que 0") @DecimalMax("99999.99")
            @Digits(integer = 6, fraction = 2) java.math.BigDecimal precio,
            @Schema(description = "Opcional: por defecto, la unidad propia del inmueble (habitación, plaza o trastero)")
            TipoUnidad tipo,
            @Schema(description = "m², opcional") @DecimalMin("0.5") @DecimalMax("9999.99") @Digits(integer = 4, fraction = 2)
            java.math.BigDecimal metros,
            @Schema(description = "Opcional, p. ej. -1") @Size(max = 20) @Pattern(regexp = HabitacionRequest.PATRON_PLANTA) String planta,
            @Schema(description = "Solo plazas de garaje: coche o moto") Vehiculo vehiculo) {

        public HabitacionInicial(Integer numero, java.math.BigDecimal precio) {
            this(numero, precio, null, null, null, null);
        }
    }
}
