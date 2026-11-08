package com.gestionap.api.domain;

import java.util.Set;

/** Pisos.tipo (V12). Los nombres coinciden con los valores del ENUM de la BD. */
public enum TipoInmueble {
    vivienda(TipoUnidad.habitacion, Set.of(TipoUnidad.habitacion)),
    /** Un garaje puede tener también algún trastero (es habitual en los sótanos). */
    garajes(TipoUnidad.plaza, Set.of(TipoUnidad.plaza, TipoUnidad.trastero)),
    trasteros(TipoUnidad.trastero, Set.of(TipoUnidad.trastero));

    private final TipoUnidad unidadPorDefecto;
    private final Set<TipoUnidad> admitidas;

    TipoInmueble(TipoUnidad unidadPorDefecto, Set<TipoUnidad> admitidas) {
        this.unidadPorDefecto = unidadPorDefecto;
        this.admitidas = admitidas;
    }

    public TipoUnidad unidadPorDefecto() {
        return unidadPorDefecto;
    }

    public boolean admite(TipoUnidad unidad) {
        return admitidas.contains(unidad);
    }
}
