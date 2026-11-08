package com.gestionap.api.security;

import tools.jackson.databind.ObjectMapper;
import com.gestionap.api.web.ErrorResponse;
import org.springframework.http.MediaType;

import com.gestionap.api.repository.UsuarioRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * Lee "Authorization: Bearer ..." y, si el token es válido, carga el usuario
 * de la BD. Se consulta en cada petición a propósito: un usuario desactivado
 * o con el rol cambiado desde el escritorio pierde el acceso al momento, sin
 * esperar a que caduque el token.
 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final String PREFIJO = "Bearer ";

    private final JwtService jwtService;
    private final UsuarioRepository usuarios;
    private final ObjectMapper json;

    public JwtAuthenticationFilter(JwtService jwtService, UsuarioRepository usuarios, ObjectMapper json) {
        this.jwtService = jwtService;
        this.usuarios = usuarios;
        this.json = json;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String cabecera = req.getHeader(HttpHeaders.AUTHORIZATION);
        if (cabecera != null && cabecera.startsWith(PREFIJO)) {
            var usuario = jwtService.validar(cabecera.substring(PREFIJO.length()))
                    .flatMap(usuarios::findById)
                    .filter(u -> u.isActivo());
            if (usuario.isPresent()) {
                if (usuario.get().isDebeCambiarPassword() && !permitidoSinCambiarPassword(req)) {
                    res.setStatus(HttpServletResponse.SC_FORBIDDEN);
                    res.setContentType(MediaType.APPLICATION_JSON_VALUE);
                    res.setCharacterEncoding("UTF-8");
                    json.writeValue(res.getOutputStream(), ErrorResponse.de(403, "PASSWORD_CADUCADA",
                            "Tienes que cambiar tu contraseña antes de seguir", req.getRequestURI()));
                    return;
                }
                UsuarioAutenticado u = UsuarioAutenticado.de(usuario.get());
                var auth = new UsernamePasswordAuthenticationToken(
                        u, null, List.of(new SimpleGrantedAuthority("ROLE_" + u.rol().name())));
                SecurityContextHolder.getContext().setAuthentication(auth);
            }
        }
        chain.doFilter(req, res);
    }

    /** Con la contraseña caducada solo se puede ver el perfil, cambiarla y quitar el dispositivo al salir. */
    private static boolean permitidoSinCambiarPassword(HttpServletRequest req) {
        String ruta = req.getRequestURI();
        String metodo = req.getMethod();
        return ("GET".equals(metodo) && "/api/me".equals(ruta))
                || ("PUT".equals(metodo) && "/api/me/password".equals(ruta))
                || ("DELETE".equals(metodo) && ruta.startsWith("/api/dispositivos/"));
    }
}
