package com.gestionap.api.web.dto;

import com.gestionap.api.domain.EstadoHabitacion;
import jakarta.validation.constraints.NotNull;

public record CambioEstadoHabitacionRequest(@NotNull EstadoHabitacion estado) {}
