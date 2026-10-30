package com.gestionap.api.web.dto;

import com.gestionap.api.domain.EstadoIncidencia;
import com.gestionap.api.domain.Incidencia;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.time.LocalDate;

public final class IncidenciaDtos {

    private IncidenciaDtos() {}

    public record IncidenciaResponse(Integer id, String descripcion, EstadoIncidencia estado, LocalDate fecha,
                                     BigDecimal costeReparacion, HabitacionBreve habitacion, PisoBreve piso,
                                     InquilinoBreve inquilino, @Schema(description = "Días desde que se comunicó") long dias) {

        public record HabitacionBreve(Integer id, int numero) {}

        public record InquilinoBreve(Integer id, String nombre) {}

        public static IncidenciaResponse de(Incidencia i, LocalDate hoy) {
            var h = i.getHabitacion();
            return new IncidenciaResponse(i.getId(), i.getDescripcion(), i.getEstado(), i.getFecha(),
                    i.getCosteReparacion() == null ? BigDecimal.ZERO : i.getCosteReparacion(),
                    new HabitacionBreve(h.getId(), h.getNumero()), PisoBreve.de(h.getPiso()),
                    new InquilinoBreve(i.getInquilino().getId(), i.getInquilino().getNombreCompleto()),
                    java.time.temporal.ChronoUnit.DAYS.between(i.getFecha(), hoy));
        }
    }

    public record IncidenciaRequest(
            @Schema(description = "Obligatoria para propietarios; un inquilino usa la de su contrato activo") Integer idHabitacion,
            @Schema(description = "Opcional: si falta, el inquilino del contrato activo de la habitación") Integer idInquilino,
            @NotBlank @Size(max = 255) String descripcion,
            @PastOrPresent(message = "no puede ser una fecha futura") LocalDate fecha,
            @PositiveOrZero @DecimalMax("99999.99") @Digits(integer = 6, fraction = 2) BigDecimal costeReparacion) {}

    public record CambioEstadoRequest(
            @Schema(description = "Opcional: si falta, avanza un paso (pendiente → en proceso → resuelta)") EstadoIncidencia estado) {}

    public record ActualizarIncidenciaRequest(
            @Size(min = 1, max = 255) String descripcion,
            @PositiveOrZero @DecimalMax("99999.99") @Digits(integer = 6, fraction = 2) BigDecimal costeReparacion) {}
}
