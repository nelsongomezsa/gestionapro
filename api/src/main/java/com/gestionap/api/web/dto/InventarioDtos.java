package com.gestionap.api.web.dto;

import com.gestionap.api.domain.ElementoInventario;
import com.gestionap.api.domain.Inventario;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.List;

public final class InventarioDtos {

    private InventarioDtos() {}

    public record ElementoRequest(
            @NotBlank @Size(max = 100) String nombre,
            @NotNull ElementoInventario.Estado estado,
            @Size(max = 255) String observaciones) {}

    public record InventarioRequest(
            @NotNull Inventario.Tipo tipo,
            @NotNull LocalDate fecha,
            Integer idContrato,
            @Size(max = 2000) String observaciones,
            @NotEmpty @Size(max = 60) List<@Valid ElementoRequest> elementos) {}

    public record Elemento(Integer id, String nombre, ElementoInventario.Estado estado, String observaciones, boolean tieneFoto) {
        static Elemento de(ElementoInventario e) {
            return new Elemento(e.getId(), e.getNombre(), e.getEstado(), e.getObservaciones(), e.getFotoRuta() != null);
        }
    }

    public record InventarioResponse(
            Integer id,
            Integer idHabitacion,
            int numeroHabitacion,
            PisoBreve piso,
            Integer idContrato,
            String inquilino,
            Inventario.Tipo tipo,
            LocalDate fecha,
            String observaciones,
            List<Elemento> elementos) {

        public static InventarioResponse de(Inventario i) {
            var h = i.getHabitacion();
            var c = i.getContrato();
            return new InventarioResponse(i.getId(), h.getId(), h.getNumero(), PisoBreve.de(h.getPiso()),
                    c != null ? c.getId() : null, c != null ? c.getInquilino().getNombreCompleto() : null,
                    i.getTipo(), i.getFecha(), i.getObservaciones(), i.getElementos().stream().map(Elemento::de).toList());
        }
    }
}
