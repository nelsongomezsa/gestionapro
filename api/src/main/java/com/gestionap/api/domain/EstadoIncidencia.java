package com.gestionap.api.domain;

/** Incidencias.estado. Los nombres coinciden con los valores del ENUM de la BD. */
public enum EstadoIncidencia {
    pendiente, en_proceso, resuelta;

    /** Siguiente paso del flujo pendiente → en proceso → resuelta; null si ya está resuelta. */
    public EstadoIncidencia siguiente() {
        return switch (this) {
            case pendiente -> en_proceso;
            case en_proceso -> resuelta;
            case resuelta -> null;
        };
    }
}
