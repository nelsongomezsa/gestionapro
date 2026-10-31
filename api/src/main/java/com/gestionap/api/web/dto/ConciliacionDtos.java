package com.gestionap.api.web.dto;

import com.gestionap.api.domain.MetodoPago;
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
    public record Confirmacion(Integer idContrato, LocalDate fecha, BigDecimal importe, MetodoPago metodoPago) {}
    public record ConfirmarRequest(List<Confirmacion> pagos) {}
    public record ConfirmarResponse(List<PagoResponse> pagos) {}
}
