package com.gestionap.api.web.dto;

import com.gestionap.api.domain.MetodoPago;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/** DTOs para analizar y confirmar una conciliación bancaria. */
public final class ConciliacionDtos {
    private ConciliacionDtos() {}

    public record Movimiento(LocalDate fecha, String concepto, BigDecimal importe, BigDecimal saldo) {}
    public record Propuesta(Integer idContrato, String inquilino, Integer numeroHabitacion,
                            String direccion, BigDecimal renta, int puntuacion, String confianza,
                            boolean yaRegistrado, boolean preseleccionada) {}
    public record MovimientoAnalizado(int indice, Movimiento movimiento, Propuesta propuesta) {}
    public record Analisis(List<MovimientoAnalizado> propuestas, List<Movimiento> sinPropuesta) {}
    /** Mismas reglas que un pago registrado a mano (PagoRequest). */
    public record Confirmacion(
            @NotNull Integer idContrato,
            @NotNull @PastOrPresent(message = "no puede ser una fecha futura") LocalDate fecha,
            @NotNull @DecimalMin(value = "0.01", message = "debe ser mayor que 0") @DecimalMax("99999.99")
            @Digits(integer = 6, fraction = 2) BigDecimal importe,
            MetodoPago metodoPago) {}
    public record ConfirmarRequest(
            @NotEmpty(message = "selecciona al menos un pago") @Size(max = 500) List<@NotNull @Valid Confirmacion> pagos) {}
    public record ConfirmarResponse(List<PagoResponse> pagos) {}
}
