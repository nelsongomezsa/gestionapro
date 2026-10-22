package com.gestionap.api.service;

import com.gestionap.api.domain.Invitacion;
import com.gestionap.api.domain.Inquilino;
import com.gestionap.api.domain.Rol;
import com.gestionap.api.domain.Usuario;
import com.gestionap.api.repository.InquilinoRepository;
import com.gestionap.api.repository.InvitacionRepository;
import com.gestionap.api.repository.UsuarioRepository;
import com.gestionap.api.security.JwtService;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.RegistroInquilinoRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.Locale;

@Service
public class AuthService {

    /** BCrypt solo usa los primeros 72 bytes; más largo se rechaza en vez de truncarlo en silencio. */
    private static final int MAX_BYTES_PASSWORD = 72;
    private static final int MAX_NOMBRE = 100;

    private final UsuarioRepository usuarios;
    private final InquilinoRepository inquilinos;
    private final InvitacionRepository invitaciones;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final ActividadService actividad;
    /** Hash de relleno: si el email no existe se compara igual, para no delatarlo por el tiempo de respuesta. */
    private final String hashRelleno;

    public AuthService(UsuarioRepository usuarios, InquilinoRepository inquilinos,
                       InvitacionRepository invitaciones, PasswordEncoder encoder,
                       JwtService jwt, ActividadService actividad) {
        this.usuarios = usuarios;
        this.inquilinos = inquilinos;
        this.invitaciones = invitaciones;
        this.encoder = encoder;
        this.jwt = jwt;
        this.actividad = actividad;
        this.hashRelleno = encoder.encode("relleno-para-igualar-tiempos");
    }

    public record Sesion(Usuario usuario, JwtService.Token token) {}

    @Transactional
    public Sesion login(String email, String password) {
        Usuario u = usuarios.findByEmail(normalizarEmail(email)).orElse(null);
        boolean ok = encoder.matches(password, u != null ? u.getPasswordHash() : hashRelleno);
        if (u == null || !ok || !u.isActivo()) {
            throw ApiException.noAutorizado("CREDENCIALES_INCORRECTAS", "Email o contraseña incorrectos");
        }
        // Igual que el escritorio: un hash SHA-256 antiguo se sustituye por BCrypt al entrar.
        if (encoder.upgradeEncoding(u.getPasswordHash())) {
            u.setPasswordHash(encoder.encode(password));
        }
        actividad.registrar(u.getId(), "LOGIN_API", "Inicio de sesión desde la app móvil");
        return new Sesion(u, jwt.generar(u));
    }

    /**
     * Crea la cuenta de un inquilino a partir de un código de invitación y la
     * enlaza con su registro en Inquilinos. Todo en una transacción, con la
     * invitación y el inquilino bloqueados: el código solo puede usarse una vez.
     */
    @Transactional
    public Sesion registrarInquilino(RegistroInquilinoRequest req) {
        if (req.password().getBytes(StandardCharsets.UTF_8).length > MAX_BYTES_PASSWORD) {
            throw ApiException.badRequest("PASSWORD_DEMASIADO_LARGA", "La contraseña es demasiado larga");
        }
        LocalDateTime ahora = LocalDateTime.now();
        Invitacion inv = invitaciones.findByCodigoHash(InvitacionService.hashCodigo(req.codigo()))
                .filter(i -> i.esUsable(ahora))
                .orElseThrow(() -> ApiException.badRequest("INVITACION_NO_VALIDA",
                        "El código de invitación no existe, ya se ha usado o ha caducado"));

        Inquilino inquilino = inquilinos.findByIdParaActualizar(inv.getInquilino().getId())
                .orElseThrow(() -> ApiException.noEncontrado("Inquilino"));
        if (inquilino.getUsuario() != null) {
            throw ApiException.conflicto("INQUILINO_YA_REGISTRADO", "Este inquilino ya tiene una cuenta");
        }

        String email = normalizarEmail(req.email());
        if (usuarios.existsByEmail(email)) {
            throw ApiException.conflicto("EMAIL_EN_USO", "Ya existe una cuenta con ese email");
        }

        Usuario u = new Usuario();
        u.setNombre(truncar(inquilino.getNombreCompleto(), MAX_NOMBRE));
        u.setEmail(email);
        u.setDni(inquilino.getDni());
        u.setPasswordHash(encoder.encode(req.password()));
        u.setRol(Rol.INQUILINO);
        u.setActivo(true);
        usuarios.save(u);

        inquilino.setUsuario(u);
        inv.setFechaUso(ahora);
        actividad.registrar(u.getId(), "REGISTRO_INQUILINO",
                "Cuenta creada con invitación para el inquilino #" + inquilino.getId());
        return new Sesion(u, jwt.generar(u));
    }

    static String normalizarEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private static String truncar(String s, int max) {
        return s.length() > max ? s.substring(0, max) : s;
    }
}
