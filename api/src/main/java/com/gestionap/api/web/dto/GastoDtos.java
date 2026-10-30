package com.gestionap.api.web.dto;

import com.gestionap.api.domain.Gasto;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public final class GastoDtos {

    private GastoDtos() {}

    public record GastoRequest(
            @NotNull Integer idPiso,
            Integer idHabitacion,
            @NotNull Gasto.Categoria categoria,
            @NotBlank @Size(max = 200) String concepto,
            @NotNull @DecimalMin(value = "0.0", inclusive = false) BigDecimal importe,
            @NotNull LocalDate fecha,
            boolean deducible) {}

    public record GastoResponse(
            Integer id,
            Integer idPiso,
            String direccionPiso,
            Integer idHabitacion,
            Integer numeroHabitacion,
            Integer idIncidencia,
            Gasto.Categoria categoria,
            String concepto,
            BigDecimal importe,
            LocalDate fecha,
            boolean deducible,
            boolean tieneFactura) {

        public static GastoResponse de(Gasto gasto) {
            return new GastoResponse(gasto.getId(), gasto.getPiso().getId(), gasto.getPiso().getDireccion(),
                    gasto.getHabitacion() != null ? gasto.getHabitacion().getId() : null,
                    gasto.getHabitacion() != null ? gasto.getHabitacion().getNumero() : null,
                    gasto.getIdIncidencia(), gasto.getCategoria(), gasto.getConcepto(), gasto.getImporte(),
                    gasto.getFecha(), gasto.isDeducible(), gasto.getFacturaRuta() != null);
        }
    }

    public record ResumenGastos(List<GastoResponse> lista, BigDecimal total, BigDecimal totalDeducible) {}
}
