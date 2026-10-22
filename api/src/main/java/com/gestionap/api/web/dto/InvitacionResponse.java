package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDateTime;

public record InvitacionResponse(
        @Schema(description = "Se muestra solo esta vez: la BD guarda únicamente su hash")
        String codigo,
        Integer idInquilino,
        LocalDateTime expira,
        @Schema(description = "true si se envió por email al inquilino")
        boolean emailEnviado) {}
