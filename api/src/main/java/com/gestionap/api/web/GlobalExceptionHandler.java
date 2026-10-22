package com.gestionap.api.web;

import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authorization.AuthorizationDeniedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.time.Instant;
import java.util.List;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ApiException.class)
    ResponseEntity<ErrorResponse> api(ApiException e, HttpServletRequest req) {
        return responder(e.getStatus(), e.getCodigo(), e.getMessage(), req);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ErrorResponse> validacion(MethodArgumentNotValidException e, HttpServletRequest req) {
        List<ErrorResponse.CampoError> errores = e.getBindingResult().getFieldErrors().stream()
                .map(f -> new ErrorResponse.CampoError(f.getField(), f.getDefaultMessage()))
                .toList();
        var cuerpo = new ErrorResponse(Instant.now(), 400, "VALIDACION",
                "Hay campos con valores no válidos", req.getRequestURI(), errores);
        return ResponseEntity.badRequest().body(cuerpo);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ErrorResponse> jsonIlegible(HttpMessageNotReadableException e, HttpServletRequest req) {
        return responder(HttpStatus.BAD_REQUEST, "JSON_INVALIDO", "El cuerpo de la petición no es un JSON válido", req);
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    ResponseEntity<ErrorResponse> tipoParametro(MethodArgumentTypeMismatchException e, HttpServletRequest req) {
        return responder(HttpStatus.BAD_REQUEST, "PARAMETRO_INVALIDO",
                "Valor no válido para '" + e.getName() + "'", req);
    }

    @ExceptionHandler({AccessDeniedException.class, AuthorizationDeniedException.class})
    ResponseEntity<ErrorResponse> accesoDenegado(RuntimeException e, HttpServletRequest req) {
        return responder(HttpStatus.FORBIDDEN, "ACCESO_DENEGADO", "No tienes permiso para esta operación", req);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<ErrorResponse> integridad(DataIntegrityViolationException e, HttpServletRequest req) {
        log.info("Violación de integridad en {}: {}", req.getRequestURI(), e.getMostSpecificCause().getMessage());
        return responder(HttpStatus.CONFLICT, "CONFLICTO_DATOS",
                "La operación entra en conflicto con datos existentes (p. ej. tiene registros asociados)", req);
    }

    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<ErrorResponse> rutaNoExiste(NoResourceFoundException e, HttpServletRequest req) {
        return responder(HttpStatus.NOT_FOUND, "RUTA_NO_ENCONTRADA", "No existe " + req.getRequestURI(), req);
    }

    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    ResponseEntity<ErrorResponse> metodo(HttpRequestMethodNotSupportedException e, HttpServletRequest req) {
        return responder(HttpStatus.METHOD_NOT_ALLOWED, "METODO_NO_PERMITIDO", e.getMessage(), req);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ErrorResponse> inesperado(Exception e, HttpServletRequest req) {
        log.error("Error no controlado en {}", req.getRequestURI(), e);
        return responder(HttpStatus.INTERNAL_SERVER_ERROR, "ERROR_INTERNO", "Error interno del servidor", req);
    }

    private ResponseEntity<ErrorResponse> responder(HttpStatus status, String codigo, String mensaje,
                                                    HttpServletRequest req) {
        return ResponseEntity.status(status)
                .body(ErrorResponse.de(status.value(), codigo, mensaje, req.getRequestURI()));
    }
}
