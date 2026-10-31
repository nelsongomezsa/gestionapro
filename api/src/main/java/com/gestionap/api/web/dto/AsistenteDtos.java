package com.gestionap.api.web.dto;

import com.fasterxml.jackson.annotation.JsonPropertyDescription;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.Map;

public final class AsistenteDtos {

    private AsistenteDtos() {}

    public record Estado(boolean disponible, String mensaje, long usadosHoy, int limiteDiario) {}

    public record Turno(@NotNull Boolean delUsuario, @NotBlank @Size(max = 4000) String texto) {}

    public record Pregunta(@NotBlank @Size(max = 2000) String mensaje, @Size(max = 20) List<@Valid Turno> historial) {}

    /**
     * Acción que propone el asistente y que la app solo ejecuta si el usuario la confirma
     * (con los endpoints de siempre): REGISTRAR_PAGO, CREAR_INCIDENCIA o RECORDATORIO.
     */
    public record Accion(String tipo, String resumen, Map<String, Object> datos) {}

    public record Contestacion(String respuesta, List<Accion> acciones, long usadosHoy, int limiteDiario) {}

    public record DescripcionIncidencia(@NotBlank @Size(max = 255) String descripcion) {}

    /** Salida estructurada al clasificar una incidencia. */
    public record ClasificacionIncidencia(
            @JsonPropertyDescription("Una de: FONTANERIA, ELECTRICIDAD, CERRAJERIA, ELECTRODOMESTICOS, CLIMATIZACION, PLAGAS, MOBILIARIO, ESTRUCTURA, OTROS")
            String categoria,
            @JsonPropertyDescription("ALTA si hay riesgo para personas, agua o electricidad sin control o la vivienda queda inhabitable; MEDIA si impide un uso normal; BAJA si puede esperar")
            String urgencia,
            @JsonPropertyDescription("Una frase en español que explica la urgencia")
            String motivo) {}

    /** Salida estructurada al leer la foto de una factura. */
    public record PropuestaGasto(
            @JsonPropertyDescription("Nombre del emisor de la factura")
            String proveedor,
            @JsonPropertyDescription("Concepto breve en español, p. ej. 'Reparación de la caldera'")
            String concepto,
            @JsonPropertyDescription("Fecha de la factura en formato aaaa-mm-dd, o vacío si no se lee")
            String fecha,
            @JsonPropertyDescription("Importe total con IVA, en euros (número)")
            double importe,
            @JsonPropertyDescription("Una de: COMUNIDAD, IBI, SEGURO, SUMINISTROS, REPARACION, MANTENIMIENTO, MOBILIARIO, INTERESES, GESTION, OTROS")
            String categoria,
            @JsonPropertyDescription("Dudas al leerla (texto borroso, importe poco claro), o vacío")
            String observaciones) {}
}
