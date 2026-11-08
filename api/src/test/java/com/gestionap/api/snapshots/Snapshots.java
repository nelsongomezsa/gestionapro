package com.gestionap.api.snapshots;

import org.junit.jupiter.api.extension.AfterAllCallback;
import org.junit.jupiter.api.extension.BeforeEachCallback;
import org.junit.jupiter.api.extension.ExtensionContext;
import org.springframework.test.web.servlet.MvcResult;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * Red de seguridad para cambios de versión: guarda cada respuesta HTTP de los tests (estado, tipo y
 * cuerpo en {@link JsonCanonico forma canónica}) y la compara con la referencia de
 * {@code src/test/resources/snapshots/}.
 * <ul>
 *   <li>{@code mvn test -Dsnapshots=grabar}: reescribe las referencias.</li>
 *   <li>{@code mvn test -Dsnapshots=comparar}: falla la clase de test cuya salida no sea idéntica
 *       (la salida real queda en {@code target/snapshots-actual/}).</li>
 *   <li>Sin la propiedad no hace nada: las referencias dependen del día (cobros del mes, atrasos).</li>
 * </ul>
 * Se registra sola en JUnit (autodetección) y en MockMvc ({@link GrabadoraMockMvc}).
 */
public class Snapshots implements BeforeEachCallback, AfterAllCallback {

    static final Path REFERENCIAS = Path.of("src/test/resources/snapshots");
    static final Path ACTUAL = Path.of("target/snapshots-actual");

    private static final String MODO = System.getProperty("snapshots", "");
    private static String clase;
    private static String test;
    private static final Map<String, Map<String, List<String>>> respuestas = new LinkedHashMap<>();

    static boolean activo() {
        return MODO.equals("grabar") || MODO.equals("comparar");
    }

    @Override
    public void beforeEach(ExtensionContext ctx) {
        clase = ctx.getRequiredTestClass().getSimpleName();
        test = ctx.getRequiredTestMethod().getName()
                + (ctx.getDisplayName().startsWith(ctx.getRequiredTestMethod().getName()) ? "" : " " + ctx.getDisplayName());
    }

    static void registrar(MvcResult r) throws Exception {
        if (clase == null) return;
        var req = r.getRequest();
        var res = r.getResponse();
        String tipo = res.getContentType() == null ? "-" : res.getContentType();
        String cuerpo;
        byte[] bytes = res.getContentAsByteArray();
        if (bytes.length == 0) {
            cuerpo = "<vacío>";
        } else if (tipo.contains("json")) {
            String texto = new String(bytes, StandardCharsets.UTF_8);
            String canon = JsonCanonico.canonico(texto);
            cuerpo = canon != null ? canon : "<JSON no válido> " + texto;
        } else if (tipo.startsWith("text/")) {
            cuerpo = new String(bytes, StandardCharsets.UTF_8);
        } else if (new String(bytes, 0, Math.min(5, bytes.length), StandardCharsets.ISO_8859_1).equals("%PDF-")) {
            cuerpo = "<pdf>";
        } else {
            cuerpo = "<binario>";
        }
        String linea = req.getMethod() + " " + JsonCanonico.ruta(req.getRequestURI())
                + (req.getQueryString() != null ? "?" + req.getQueryString() : "");
        respuestas.computeIfAbsent(clase, k -> new TreeMap<>())
                .computeIfAbsent(test, k -> new ArrayList<>())
                .add(linea + "\n" + res.getStatus() + " " + tipo + "\n" + cuerpo);
    }

    @Override
    public void afterAll(ExtensionContext ctx) throws IOException {
        if (!activo()) return;
        String nombre = ctx.getRequiredTestClass().getSimpleName();
        Map<String, List<String>> porTest = respuestas.remove(nombre);
        clase = null;
        if (porTest == null) return;
        String texto = formatear(porTest);
        Path archivo = (MODO.equals("grabar") ? REFERENCIAS : ACTUAL).resolve(nombre + ".txt");
        Files.createDirectories(archivo.getParent());
        Files.writeString(archivo, texto);
        if (MODO.equals("comparar")) {
            Path ref = REFERENCIAS.resolve(nombre + ".txt");
            String esperado = Files.exists(ref) ? Files.readString(ref) : "";
            if (!esperado.equals(texto)) {
                throw new AssertionError("Las respuestas de " + nombre + " no coinciden con la referencia: "
                        + primeraDiferencia(esperado, texto) + " (diff " + ref + " " + archivo + ")");
            }
        }
    }

    private static String formatear(Map<String, List<String>> porTest) {
        StringBuilder sb = new StringBuilder();
        porTest.forEach((t, lista) -> {
            for (int n = 0; n < lista.size(); n++) {
                sb.append("### ").append(t).append(" #").append(n + 1).append('\n').append(lista.get(n)).append("\n\n");
            }
        });
        return sb.toString();
    }

    private static String primeraDiferencia(String a, String b) {
        String[] la = a.split("\n", -1);
        String[] lb = b.split("\n", -1);
        String seccion = "";
        for (int n = 0; n < Math.max(la.length, lb.length); n++) {
            String x = n < la.length ? la[n] : "<fin>";
            String y = n < lb.length ? lb[n] : "<fin>";
            if (x.startsWith("### ")) seccion = x;
            if (!x.equals(y)) return "línea " + (n + 1) + " [" + seccion + "] esperado «" + x + "», recibido «" + y + "»";
        }
        return "?";
    }
}
