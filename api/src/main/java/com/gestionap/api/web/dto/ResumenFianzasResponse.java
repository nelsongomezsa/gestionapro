package com.gestionap.api.web.dto;

import java.math.BigDecimal;
import java.util.List;

/** Fianzas visibles y lo que suman las que aún hay que devolver. */
public record ResumenFianzasResponse(List<FianzaResponse> fianzas, BigDecimal totalPendienteDevolver) {
}
