package com.gestionap.api.web;

import java.time.Instant;
import java.util.List;

/**
 * Formato único de error de toda la API (también para 401/403 de seguridad).
 *
 * @param codigo  identificador estable (VALIDACION, NO_ENCONTRADO, CREDENCIALES_INCORRECTAS...)
 * @param errores detalle por campo; solo en errores de validación
 */
public record ErrorResponse(
        Instant timestamp,
        int status,
        String codigo,
        String mensaje,
        String path,
        List<CampoError> errores) {

    public record CampoError(String campo, String mensaje) {}

    public static ErrorResponse de(int status, String codigo, String mensaje, String path) {
        return new ErrorResponse(Instant.now(), status, codigo, mensaje, path, null);
    }
}
