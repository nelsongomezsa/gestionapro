package com.gestionap.api.security;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.HexFormat;
import java.util.Locale;

/**
 * Comprueba si una contraseña aparece en filtraciones conocidas (Have I Been Pwned, Pwned Passwords).
 * k-anonymity: solo se envían los 5 primeros caracteres del SHA-1; la comparación del resto se hace aquí.
 * Si el servicio no responde, no se bloquea al usuario: se deja constancia en el log y se acepta.
 */
@Slf4j
@Component
public class ContrasenasFiltradas {

    private final String url;
    private final HttpClient http;

    public ContrasenasFiltradas(@Value("${gestionap.hibp.url:https://api.pwnedpasswords.com/range/}") String url) {
        this.url = url;
        this.http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).build();
    }

    /** true si la contraseña aparece en alguna filtración; false si no aparece, el servicio falla o está desactivado. */
    public boolean filtrada(String password) {
        if (url == null || url.isBlank()) return false;
        String sha1 = sha1(password);
        String prefijo = sha1.substring(0, 5);
        String sufijo = sha1.substring(5);
        try {
            HttpRequest peticion = HttpRequest.newBuilder(URI.create(url + prefijo))
                    .timeout(Duration.ofSeconds(3))
                    // Relleno: el tamaño de la respuesta no delata el prefijo consultado.
                    .header("Add-Padding", "true")
                    .header("User-Agent", "gestionapro-api")
                    .GET().build();
            HttpResponse<String> r = http.send(peticion, HttpResponse.BodyHandlers.ofString());
            if (r.statusCode() != 200) {
                log.warn("HIBP respondió {}: la contraseña se acepta sin comprobar", r.statusCode());
                return false;
            }
            return r.body().lines().anyMatch(linea -> {
                int dosPuntos = linea.indexOf(':');
                return dosPuntos > 0
                        && linea.substring(0, dosPuntos).trim().equalsIgnoreCase(sufijo)
                        && !linea.substring(dosPuntos + 1).trim().equals("0"); // las de relleno vienen con 0
            });
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.warn("Consulta a HIBP interrumpida: la contraseña se acepta sin comprobar");
            return false;
        } catch (Exception e) {
            log.warn("HIBP no disponible ({}): la contraseña se acepta sin comprobar", e.getClass().getSimpleName());
            return false;
        }
    }

    static String sha1(String texto) {
        try {
            byte[] h = MessageDigest.getInstance("SHA-1").digest(texto.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(h).toUpperCase(Locale.ROOT);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-1 no disponible", e);
        }
    }
}
