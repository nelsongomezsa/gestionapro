package com.gestionap.api.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/** En la lista, contratos y pagos van vacíos; en la ficha (GET /api/inquilinos/{id}) van completos. */
public record InquilinoResponse(
        Integer id,
        String nombre,
        String apellidos,
        String dni,
        String telefono,
        String email,
        @Schema(description = "Tiene cuenta en la app móvil") boolean tieneCuentaApp,
        @Schema(description = "Contrato activo hoy, si lo hay") ContratoBreve contratoActivo,
        List<ContratoBreve> contratos,
        List<PagoBreve> pagos) {}
