package com.gestionap.api.service;

import com.gestionap.api.domain.Habitacion;
import com.gestionap.api.domain.TipoInmueble;
import com.gestionap.api.domain.TipoUnidad;
import com.gestionap.api.domain.Vehiculo;
import com.gestionap.api.web.ApiException;

import java.math.BigDecimal;

/** Reglas de las unidades de un inmueble (V12): qué tipo cabe en cada inmueble y sus datos opcionales. */
final class Unidades {

    private Unidades() {}

    /** Tipo de la unidad: el pedido o, si no se indica, el propio del inmueble. */
    static TipoUnidad tipo(TipoInmueble inmueble, TipoUnidad pedido) {
        TipoUnidad t = pedido != null ? pedido : inmueble.unidadPorDefecto();
        if (!inmueble.admite(t)) {
            throw ApiException.badRequest("TIPO_UNIDAD_NO_VALIDO",
                    "Un inmueble de tipo " + inmueble.name() + " no admite unidades de tipo " + t.name());
        }
        return t;
    }

    /** Aplica tipo, m², planta y vehículo (este, solo en plazas de garaje). */
    static void aplicar(Habitacion h, TipoInmueble inmueble, TipoUnidad tipo, BigDecimal metros, String planta, Vehiculo vehiculo) {
        TipoUnidad t = tipo(inmueble, tipo);
        if (vehiculo != null && t != TipoUnidad.plaza) {
            throw ApiException.badRequest("VEHICULO_NO_VALIDO", "Coche o moto solo se indica en plazas de garaje");
        }
        h.setTipo(t);
        h.setMetros(metros);
        h.setPlanta(planta == null || planta.isBlank() ? null : planta.trim());
        h.setVehiculo(vehiculo);
    }
}
