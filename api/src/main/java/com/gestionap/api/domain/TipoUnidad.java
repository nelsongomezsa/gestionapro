package com.gestionap.api.domain;

/** Habitaciones.tipo (V12): lo que se alquila. Los nombres coinciden con los valores del ENUM de la BD. */
public enum TipoUnidad {
    habitacion("habitación", "habitaciones", "Hab.", true),
    plaza("plaza", "plazas", "Plaza", true),
    trastero("trastero", "trasteros", "Trastero", false);

    private final String nombre;
    private final String plural;
    private final String abreviatura;
    private final boolean femenino;

    TipoUnidad(String nombre, String plural, String abreviatura, boolean femenino) {
        this.nombre = nombre;
        this.plural = plural;
        this.abreviatura = abreviatura;
        this.femenino = femenino;
    }

    /** "La habitación", "La plaza", "El trastero" (para empezar una frase). */
    public String conArticulo() {
        return (femenino ? "La " : "El ") + nombre;
    }

    /** "una habitación", "una plaza", "un trastero". */
    public String conIndefinido() {
        return (femenino ? "una " : "un ") + nombre;
    }

    /** "habitación", "plaza", "trastero" (textos de la API y de los PDF, en español). */
    public String nombre() {
        return nombre;
    }

    public String plural() {
        return plural;
    }

    /** "Hab. 3", "Plaza 3", "Trastero 3". */
    public String etiqueta(int numero) {
        return abreviatura + " " + numero;
    }

    /** "Habitación", "Plaza", "Trastero". */
    public String titulo() {
        return Character.toUpperCase(nombre.charAt(0)) + nombre.substring(1);
    }
}
