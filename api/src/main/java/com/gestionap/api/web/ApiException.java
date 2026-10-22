package com.gestionap.api.web;

import lombok.Getter;
import org.springframework.http.HttpStatus;

/**
 * Error de negocio con su estado HTTP y un código estable que la app iOS
 * puede usar para decidir qué mostrar (el mensaje es para humanos).
 */
@Getter
public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String codigo;

    public ApiException(HttpStatus status, String codigo, String mensaje) {
        super(mensaje);
        this.status = status;
        this.codigo = codigo;
    }

    public static ApiException badRequest(String codigo, String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, codigo, mensaje);
    }

    public static ApiException noEncontrado(String recurso) {
        return new ApiException(HttpStatus.NOT_FOUND, "NO_ENCONTRADO", recurso + " no encontrado");
    }

    public static ApiException conflicto(String codigo, String mensaje) {
        return new ApiException(HttpStatus.CONFLICT, codigo, mensaje);
    }

    public static ApiException noAutorizado(String codigo, String mensaje) {
        return new ApiException(HttpStatus.UNAUTHORIZED, codigo, mensaje);
    }
}
