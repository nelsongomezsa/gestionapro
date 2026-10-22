package com.gestionap.api.security;

import com.gestionap.api.domain.Usuario;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;

@Service
public class JwtService {

    private static final String EMISOR = "gestionapro-api";

    private final SecretKey clave;
    private final JwtProperties props;

    public JwtService(JwtProperties props) {
        this.props = props;
        this.clave = Keys.hmacShaKeyFor(props.secret().getBytes(StandardCharsets.UTF_8));
    }

    public record Token(String valor, Instant expira) {}

    public Token generar(Usuario usuario) {
        Instant ahora = Instant.now();
        Instant expira = ahora.plus(props.expiracion());
        String valor = Jwts.builder()
                .issuer(EMISOR)
                .subject(String.valueOf(usuario.getId()))
                .claim("rol", usuario.getRol().name())
                .issuedAt(Date.from(ahora))
                .expiration(Date.from(expira))
                .signWith(clave)
                .compact();
        return new Token(valor, expira);
    }

    /** Id de usuario si el token es válido (firma, emisor y caducidad); vacío si no. */
    public Optional<Integer> validar(String token) {
        try {
            String sub = Jwts.parser()
                    .verifyWith(clave)
                    .requireIssuer(EMISOR)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload()
                    .getSubject();
            return Optional.of(Integer.valueOf(sub));
        } catch (JwtException | IllegalArgumentException e) {
            return Optional.empty();
        }
    }
}
