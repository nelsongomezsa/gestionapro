package com.gestionap.api.web.dto;

import java.util.List;

public record ItpResponse(String anioReferencia, List<Comunidad> comunidades) {

    public record Comunidad(String nombre, double tipoPct) {}
}
