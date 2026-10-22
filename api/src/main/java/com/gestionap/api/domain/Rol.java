package com.gestionap.api.domain;

import java.util.Arrays;

/**
 * Rol de la API. La BD guarda los valores del escritorio sin renombrar
 * (Usuarios.rol ENUM('admin','usuario','inquilino')); aquí se traducen:
 * 'usuario' es el propietario que gestiona pisos.
 */
public enum Rol {
    ADMIN("admin"),
    PROPIETARIO("usuario"),
    INQUILINO("inquilino");

    private final String valorBd;

    Rol(String valorBd) {
        this.valorBd = valorBd;
    }

    public String valorBd() {
        return valorBd;
    }

    public static Rol desdeBd(String valor) {
        return Arrays.stream(values())
                .filter(r -> r.valorBd.equals(valor))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Rol desconocido en la BD: " + valor));
    }

    @jakarta.persistence.Converter(autoApply = true)
    public static class Converter implements jakarta.persistence.AttributeConverter<Rol, String> {
        @Override public String convertToDatabaseColumn(Rol rol) { return rol == null ? null : rol.valorBd; }
        @Override public Rol convertToEntityAttribute(String valor) { return valor == null ? null : desdeBd(valor); }
    }
}
