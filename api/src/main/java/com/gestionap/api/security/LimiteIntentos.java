package com.gestionap.api.security;

import com.gestionap.api.web.ApiException;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Límite de intentos para login, registro y recuperación de contraseña.
 * Por IP cuenta todas las peticiones; por email, solo los fallos (un acierto lo pone a cero).
 * Ventana fija en memoria: con varias instancias de la API cada una lleva su cuenta.
 */
@Component
public class LimiteIntentos {

    /** Por encima de este número de claves se purgan las ventanas caducadas. */
    private static final int PURGAR_DESDE = 10_000;

    private record Ventana(Instant inicio, int cuenta) {}

    private final Map<String, Ventana> ventanas = new ConcurrentHashMap<>();
    private final Duration duracion;
    private final int maxPorIp;
    private final int maxFallosPorEmail;
    private final Clock reloj;

    @Autowired
    public LimiteIntentos(@Value("${gestionap.limites.ventana:15m}") Duration duracion,
                          @Value("${gestionap.limites.por-ip:20}") int maxPorIp,
                          @Value("${gestionap.limites.fallos-por-email:5}") int maxFallosPorEmail) {
        this(duracion, maxPorIp, maxFallosPorEmail, Clock.systemUTC());
    }

    LimiteIntentos(Duration duracion, int maxPorIp, int maxFallosPorEmail, Clock reloj) {
        this.duracion = duracion;
        this.maxPorIp = maxPorIp;
        this.maxFallosPorEmail = maxFallosPorEmail;
        this.reloj = reloj;
    }

    /** Lanza 429 si la IP o el email han agotado sus intentos; si no, cuenta la petición de la IP. */
    public void comprobar(String ip, String email) {
        Instant ahora = reloj.instant();
        if (ventanas.size() > PURGAR_DESDE) ventanas.values().removeIf(v -> caducada(v, ahora));
        exigir(claveIp(ip), maxPorIp, ahora);
        if (email != null) exigir(claveEmail(email), maxFallosPorEmail, ahora);
        sumar(claveIp(ip), ahora);
    }

    /** Acciones de un usuario ya identificado (cambiar contraseña, eliminar cuenta): solo cuentan los fallos. */
    public void comprobarUsuario(Integer idUsuario) {
        exigir(claveUsuario(idUsuario), maxFallosPorEmail, reloj.instant());
    }

    public void falloUsuario(Integer idUsuario) {
        sumar(claveUsuario(idUsuario), reloj.instant());
    }

    public void aciertoUsuario(Integer idUsuario) {
        ventanas.remove(claveUsuario(idUsuario));
    }

    private static String claveUsuario(Integer id) {
        return "usuario:" + id;
    }

    public void fallo(String email) {
        if (email != null) sumar(claveEmail(email), reloj.instant());
    }

    public void acierto(String email) {
        if (email != null) ventanas.remove(claveEmail(email));
    }

    private void exigir(String clave, int maximo, Instant ahora) {
        Ventana v = ventanas.get(clave);
        if (v == null || caducada(v, ahora) || v.cuenta() < maximo) return;
        long segundos = Math.max(1, Duration.between(ahora, v.inicio().plus(duracion)).toSeconds());
        throw ApiException.demasiadosIntentos(segundos);
    }

    private void sumar(String clave, Instant ahora) {
        ventanas.compute(clave, (k, v) -> v == null || caducada(v, ahora)
                ? new Ventana(ahora, 1) : new Ventana(v.inicio(), v.cuenta() + 1));
    }

    private boolean caducada(Ventana v, Instant ahora) {
        return !ahora.isBefore(v.inicio().plus(duracion));
    }

    private static String claveIp(String ip) {
        return "ip:" + ip;
    }

    private static String claveEmail(String email) {
        return "email:" + email.trim().toLowerCase(java.util.Locale.ROOT);
    }
}
