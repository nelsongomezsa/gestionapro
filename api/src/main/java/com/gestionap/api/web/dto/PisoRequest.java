package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

public record PisoRequest(
        @NotBlank @Size(max = 150) String direccion,
        @NotNull @Min(1) @Max(50) Integer numeroHabitaciones,
        @NotNull Integer idCiudad,
        @Schema(description = "Opcional. En un PUT, si se omite, los datos financieros guardados no cambian")
        @Valid DatosFinancierosDto datosFinancieros,
        @Schema(description = "Solo al crear (se ignora en un PUT): habitaciones que se crean con el piso, "
                + "en la misma operación. Si se envían, tantas como numeroHabitaciones y con números distintos")
        @Valid @Size(max = 50) java.util.List<HabitacionInicial> habitaciones) {

    /** Constructor sin habitaciones (edición y código existente). */
    public PisoRequest(String direccion, Integer numeroHabitaciones, Integer idCiudad, DatosFinancierosDto datosFinancieros) {
        this(direccion, numeroHabitaciones, idCiudad, datosFinancieros, null);
    }

    public record HabitacionInicial(
            @NotNull @Min(1) @Max(999) Integer numero,
            @NotNull @DecimalMin(value = "0.01", message = "debe ser mayor que 0") @DecimalMax("99999.99")
            @Digits(integer = 6, fraction = 2) java.math.BigDecimal precio) {}
}
