package com.gestionap.api.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.gestionap.api.web.ErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;

/** 401 y 403 de la cadena de seguridad con el mismo JSON que el resto de errores. */
@Component
public class JsonSecurityErrorHandler implements AuthenticationEntryPoint, AccessDeniedHandler {

    private final ObjectMapper json;

    public JsonSecurityErrorHandler(ObjectMapper json) {
        this.json = json;
    }

    @Override
    public void commence(HttpServletRequest req, HttpServletResponse res, AuthenticationException e)
            throws IOException {
        escribir(res, ErrorResponse.de(401, "NO_AUTENTICADO",
                "Falta el token de acceso o no es válido", req.getRequestURI()));
    }

    @Override
    public void handle(HttpServletRequest req, HttpServletResponse res, AccessDeniedException e)
            throws IOException {
        escribir(res, ErrorResponse.de(403, "ACCESO_DENEGADO",
                "No tienes permiso para esta operación", req.getRequestURI()));
    }

    private void escribir(HttpServletResponse res, ErrorResponse cuerpo) throws IOException {
        res.setStatus(cuerpo.status());
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        res.setCharacterEncoding("UTF-8");
        json.writeValue(res.getOutputStream(), cuerpo);
    }
}
