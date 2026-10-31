package com.gestionap.api.service;

import com.gestionap.api.domain.Dispositivo;
import com.gestionap.api.repository.DispositivoRepository;
import com.gestionap.api.web.ApiException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Jwts;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.Map;

/**
 * Notificaciones push por APNs (Apple Push Notification service), con autenticación por token
 * (clave .p8 de una cuenta de Apple Developer). Sin configurar (APNS_KEY_PATH, APNS_KEY_ID,
 * APNS_TEAM_ID) no envía nada: las notificaciones siguen en la campana de la app.
 * PREPARADO PERO SIN PROBAR EN REAL: requiere una cuenta de pago de Apple Developer.
 */
@Slf4j
@Service
public class PushService {

    private static final Duration VIGENCIA_JWT = Duration.ofMinutes(50);

    private final DispositivoRepository dispositivos;
    private final ObjectMapper json;
    private final String rutaClave;
    private final String idClave;
    private final String equipo;
    private final String bundle;
    private final String host;
    private final HttpClient http = HttpClient.newBuilder().version(HttpClient.Version.HTTP_2)
            .connectTimeout(Duration.ofSeconds(5)).build();
    private String jwt;
    private Instant jwtCreado = Instant.EPOCH;

    public PushService(DispositivoRepository dispositivos, ObjectMapper json,
                       @Value("${gestionap.push.clave:}") String rutaClave,
                       @Value("${gestionap.push.id-clave:}") String idClave,
                       @Value("${gestionap.push.equipo:}") String equipo,
                       @Value("${gestionap.push.bundle:com.gestionap.GestionApPro}") String bundle,
                       @Value("${gestionap.push.produccion:false}") boolean produccion) {
        this.dispositivos = dispositivos;
        this.json = json;
        this.rutaClave = rutaClave;
        this.idClave = idClave;
        this.equipo = equipo;
        this.bundle = bundle;
        this.host = produccion ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";
    }

    public boolean configurado() {
        return !rutaClave.isBlank() && !idClave.isBlank() && !equipo.isBlank();
    }

    /** Registra (o reasigna) el token del dispositivo al usuario que ha iniciado sesión. */
    @Transactional
    public void registrar(Integer idUsuario, String token) {
        if (token == null || !token.matches("[0-9a-fA-F]{32,200}")) {
            throw ApiException.badRequest("TOKEN_NO_VALIDO", "Token de dispositivo no válido");
        }
        String normalizado = token.toLowerCase();
        Dispositivo d = dispositivos.findByToken(normalizado).orElseGet(Dispositivo::new);
        d.setToken(normalizado);
        d.setIdUsuario(idUsuario);
        if (d.getFechaAlta() == null) d.setFechaAlta(LocalDateTime.now());
        dispositivos.save(d);
    }

    @Transactional
    public void borrar(Integer idUsuario, String token) {
        dispositivos.findByToken(token == null ? "" : token.toLowerCase())
                .filter(d -> d.getIdUsuario().equals(idUsuario))
                .ifPresent(dispositivos::delete);
    }

    /** Envía a todos los dispositivos del usuario, en segundo plano. Sin configuración no hace nada. */
    @Async
    public void enviar(Integer idUsuario, String titulo, String cuerpo) {
        if (!configurado()) return;
        for (Dispositivo d : dispositivos.findByIdUsuario(idUsuario)) {
            try {
                HttpRequest peticion = HttpRequest.newBuilder(URI.create(host + "/3/device/" + d.getToken()))
                        .timeout(Duration.ofSeconds(10))
                        .header("authorization", "bearer " + jwt())
                        .header("apns-topic", bundle)
                        .header("apns-push-type", "alert")
                        .POST(HttpRequest.BodyPublishers.ofString(cuerpo(titulo, cuerpo)))
                        .build();
                HttpResponse<String> r = http.send(peticion, HttpResponse.BodyHandlers.ofString());
                if (r.statusCode() == 410 || r.body().contains("BadDeviceToken") || r.body().contains("Unregistered")) {
                    dispositivos.delete(d);
                } else if (r.statusCode() != 200) {
                    log.warn("APNs respondió {}: {}", r.statusCode(), r.body());
                }
            } catch (Exception e) {
                if (e instanceof InterruptedException) Thread.currentThread().interrupt();
                log.warn("No se pudo enviar el push: {}", e.getMessage());
            }
        }
    }

    /** Carga útil de APNs: título, texto y el número de la campana lo pone la app al abrirse. */
    String cuerpo(String titulo, String cuerpo) throws com.fasterxml.jackson.core.JsonProcessingException {
        return json.writeValueAsString(Map.of("aps", Map.of("alert", Map.of("title", titulo, "body", cuerpo), "sound", "default")));
    }

    /** JWT ES256 firmado con la clave .p8; APNs lo acepta hasta una hora, se renueva antes. */
    private synchronized String jwt() throws Exception {
        if (jwt == null || jwtCreado.isBefore(Instant.now().minus(VIGENCIA_JWT))) {
            jwtCreado = Instant.now();
            jwt = Jwts.builder().header().keyId(idClave).and()
                    .issuer(equipo).issuedAt(java.util.Date.from(jwtCreado))
                    .signWith(clavePrivada(), Jwts.SIG.ES256).compact();
        }
        return jwt;
    }

    private PrivateKey clavePrivada() throws Exception {
        String pem = Files.readString(Path.of(rutaClave))
                .replaceAll("-----(BEGIN|END) PRIVATE KEY-----", "").replaceAll("\\s", "");
        return KeyFactory.getInstance("EC").generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(pem)));
    }
}
