package com.gestionap.api.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.TreeMap;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Variación anual del IRAV y del IPC leída de la API oficial del INE (servicios.ine.es/wstempus),
 * sin copiar cifras a mano:
 * - IRAV: serie IRAV1, "Índice de Referencia de Arrendamientos de Vivienda" (disposición
 *   adicional undécima de la LAU, añadida por la Ley 12/2023; el INE lo publica desde 2025).
 * - IPC: variación anual del índice general nacional. Desde enero de 2026 el IPC tiene base 2025
 *   (serie IPC290750); los meses anteriores salen de la serie de base 2021 (IPC251856).
 * Se guarda en memoria 12 horas. Sin conexión con el INE devuelve vacío y la app pide el porcentaje.
 *
 * El certificado de servicios.ine.es lo emite la FNMT, cuya raíz no viene en los certificados de
 * Java: se añade la raíz pública "AC RAIZ FNMT-RCM" (certs/ac-raiz-fnmt-rcm.pem, SHA-256
 * EB:C5:57:0C:…:9B:93:FA, la misma que trae macOS) solo para este cliente.
 */
@Slf4j
@Service
public class IndicesOficiales {

    public record Dato(YearMonth periodo, BigDecimal variacionAnual, String serie) {}

    private static final Duration VIGENCIA = Duration.ofHours(12);

    private final String url;
    private final Map<String, List<String>> series;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).sslContext(ssl()).build();
    private final ObjectMapper json = new ObjectMapper();
    private final Map<String, TreeMap<YearMonth, Dato>> cache = new ConcurrentHashMap<>();
    private final Map<String, Instant> leido = new ConcurrentHashMap<>();

    public IndicesOficiales(@Value("${gestionap.indices.url:https://servicios.ine.es/wstempus/js/ES/DATOS_SERIE/}") String url,
                            @Value("${gestionap.indices.irav:IRAV1}") String irav,
                            @Value("${gestionap.indices.ipc:IPC290750,IPC251856}") List<String> ipc) {
        this.url = url;
        this.series = Map.of("IRAV", List.of(irav), "IPC", ipc);
    }

    /** Certificados de Java más la raíz de la FNMT. Si algo falla, los de Java (el INE dará error y se pedirá a mano). */
    private static javax.net.ssl.SSLContext ssl() {
        try (var pem = IndicesOficiales.class.getResourceAsStream("/certs/ac-raiz-fnmt-rcm.pem")) {
            var almacen = java.security.KeyStore.getInstance(java.security.KeyStore.getDefaultType());
            almacen.load(null, null);
            var porDefecto = javax.net.ssl.TrustManagerFactory.getInstance(javax.net.ssl.TrustManagerFactory.getDefaultAlgorithm());
            porDefecto.init((java.security.KeyStore) null);
            for (var tm : porDefecto.getTrustManagers()) {
                if (tm instanceof javax.net.ssl.X509TrustManager x) {
                    int i = 0;
                    for (var c : x.getAcceptedIssuers()) almacen.setCertificateEntry("java-" + i++, c);
                }
            }
            almacen.setCertificateEntry("fnmt", java.security.cert.CertificateFactory.getInstance("X.509").generateCertificate(pem));
            var tmf = javax.net.ssl.TrustManagerFactory.getInstance(javax.net.ssl.TrustManagerFactory.getDefaultAlgorithm());
            tmf.init(almacen);
            var ctx = javax.net.ssl.SSLContext.getInstance("TLS");
            ctx.init(null, tmf.getTrustManagers(), null);
            return ctx;
        } catch (Exception e) {
            log.warn("No se pudo cargar la raíz de la FNMT: {}", e.getMessage());
            try { return javax.net.ssl.SSLContext.getDefault(); } catch (Exception ex) { throw new IllegalStateException(ex); }
        }
    }

    /** El último dato publicado como mucho del mes indicado (el índice "a fecha de" la actualización). */
    public Optional<Dato> ultimoHasta(String indice, YearMonth mes) {
        var datos = datos(indice);
        var e = datos.floorEntry(mes);
        return e == null ? Optional.empty() : Optional.of(e.getValue());
    }

    /** Para los tests (y por si un día el INE no responde): fija los datos de un índice. */
    public void fijar(String indice, Map<YearMonth, BigDecimal> valores) {
        TreeMap<YearMonth, Dato> m = new TreeMap<>();
        valores.forEach((p, v) -> m.put(p, new Dato(p, v, "manual")));
        cache.put(indice, m);
        leido.put(indice, Instant.MAX.minusSeconds(1));
    }

    private TreeMap<YearMonth, Dato> datos(String indice) {
        Instant cuando = leido.get(indice);
        if (cuando != null && (cuando.isAfter(Instant.now().minus(VIGENCIA)))) return cache.get(indice);
        if (url.isBlank()) return cache.getOrDefault(indice, new TreeMap<>());
        TreeMap<YearMonth, Dato> m = new TreeMap<>();
        // Las series más antiguas primero: si un mes está en dos (cambio de base), gana la nueva.
        List<String> codigos = series.getOrDefault(indice, List.of());
        for (int i = codigos.size() - 1; i >= 0; i--) {
            leer(codigos.get(i)).forEach(d -> m.put(d.periodo(), d));
        }
        if (!m.isEmpty()) {
            cache.put(indice, m);
            leido.put(indice, Instant.now());
        }
        return m.isEmpty() ? cache.getOrDefault(indice, m) : m;
    }

    private List<Dato> leer(String serie) {
        try {
            var req = HttpRequest.newBuilder(URI.create(url + serie + "?nult=36")).timeout(Duration.ofSeconds(10)).GET().build();
            var res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() != 200) throw new IllegalStateException("HTTP " + res.statusCode());
            JsonNode raiz = json.readTree(res.body());
            return java.util.stream.StreamSupport.stream(raiz.path("Data").spliterator(), false)
                    .filter(d -> d.hasNonNull("Valor"))
                    .map(d -> new Dato(YearMonth.of(d.get("Anyo").asInt(), d.get("FK_Periodo").asInt()),
                            d.get("Valor").decimalValue(), serie))
                    .toList();
        } catch (Exception e) {
            if (e instanceof InterruptedException) Thread.currentThread().interrupt();
            log.warn("No se pudo leer la serie {} del INE: {}", serie, e.getMessage());
            return List.of();
        }
    }
}
