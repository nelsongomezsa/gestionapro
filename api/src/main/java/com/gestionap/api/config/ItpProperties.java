package com.gestionap.api.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import jakarta.validation.constraints.NotEmpty;
import java.util.List;
import java.util.Optional;

/** Tipos de ITP por comunidad autónoma, cargados de itp-rates.yml. */
@Validated
@ConfigurationProperties("gestionap.itp")
public record ItpProperties(String anioReferencia, @NotEmpty List<Comunidad> comunidades) {

    public record Comunidad(String nombre, double tipo) {}

    public Optional<Double> tipoDe(String nombreComunidad) {
        return comunidades.stream()
                .filter(c -> c.nombre().equals(nombreComunidad))
                .map(Comunidad::tipo)
                .findFirst();
    }
}
