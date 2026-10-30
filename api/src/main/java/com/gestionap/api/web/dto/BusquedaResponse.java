package com.gestionap.api.web.dto;

import java.util.List;

/** Búsqueda global (la caja de búsqueda de la barra superior del escritorio). Hasta 10 por grupo. */
public record BusquedaResponse(List<Resultado> pisos, List<Resultado> inquilinos, List<Resultado> contratos,
                               List<Resultado> incidencias) {

    public record Resultado(Integer id, String titulo, String subtitulo) {}
}
