package com.gestionap.api.web.dto;

import com.gestionap.api.domain.Rol;
import io.swagger.v3.oas.annotations.media.Schema;

public record UsuarioResponse(
        Integer id,
        String nombre,
        String email,
        Rol rol,
        @Schema(description = "Solo para INQUILINO: su registro en Inquilinos")
        Integer idInquilino,
        String dni,
        @Schema(description = "IBAN para el QR de pago de sus inquilinos, con espacios cada 4 caracteres")
        String iban) {}
