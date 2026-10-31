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
    /** Segundos para la cabecera Retry-After (solo en 429). */
    private final Long reintentarEn;

    public ApiException(HttpStatus status, String codigo, String mensaje) {
        this(status, codigo, mensaje, null);
    }

    private ApiException(HttpStatus status, String codigo, String mensaje, Long reintentarEn) {
        super(mensaje);
        this.status = status;
        this.codigo = codigo;
        this.reintentarEn = reintentarEn;
    }

    public static ApiException demasiadosIntentos(long segundos) {
        long minutos = Math.max(1, (segundos + 59) / 60);
        return new ApiException(HttpStatus.TOO_MANY_REQUESTS, "DEMASIADOS_INTENTOS",
                "Demasiados intentos. Prueba de nuevo en " + minutos + (minutos == 1 ? " minuto" : " minutos"), segundos);
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
