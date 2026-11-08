package com.gestionap.api.snapshots;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Reescribe un JSON en un formato estable para compararlo con la referencia.
 * <p>
 * No usa Jackson a propósito: la comparación tiene que ser la misma antes y después de cambiar de
 * versión de Jackson. Conserva el orden de los campos, los nulos y el texto literal de los números
 * (1200.00 no es 1200.0 ni 1200) y de las fechas. Solo enmascara lo que cambia en cada ejecución:
 * identificadores autonuméricos, tokens JWT y fechas-hora de «ahora» (de estas se conserva el formato).
 */
public final class JsonCanonico {

    private static final Pattern JWT = Pattern.compile("^eyJ[\\w-]+\\.[\\w-]+\\.[\\w-]+$");
    private static final Pattern FECHA_HORA = Pattern.compile(
            "^(\\d{4}-\\d{2}-\\d{2})T(\\d{2}:\\d{2}(?::\\d{2})?)(\\.\\d+)?(Z|[+-]\\d{2}:\\d{2})?$");
    private static final Pattern CODIGO = Pattern.compile("^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$");
    private static final Pattern FECHA_HORA_ES = Pattern.compile("^(\\d{1,2}/\\d{1,2}/\\d{4}) \\d{2}:\\d{2}$");
    private static final Pattern SHA256 = Pattern.compile("^[0-9a-f]{64}$");
    private static final Pattern ID_EN_TEXTO = Pattern.compile("(\\\\\"(?:id|id[A-Z]\\w*|\\w+Id)\\\\\":)\\d+");
    private static final Pattern CLAVE_ID = Pattern.compile("^id([A-Z].*)?$|.*Id$");

    private final String s;
    private int i;
    private final StringBuilder out = new StringBuilder();

    private JsonCanonico(String s) {
        this.s = s;
    }

    /** JSON canónico (sangrado de 2 espacios), o null si el texto no es JSON válido. */
    public static String canonico(String texto) {
        try {
            JsonCanonico p = new JsonCanonico(texto);
            p.espacios();
            p.valor(0, null);
            p.espacios();
            if (p.i != p.s.length()) return null;
            return p.out.toString();
        } catch (RuntimeException e) {
            return null;
        }
    }

    /** Enmascara los números de una ruta (/api/pisos/123 → /api/pisos/{n}), que dependen del autonumérico. */
    public static String ruta(String uri) {
        return uri.replaceAll("/\\d+(?=/|$|\\?|\")", "/{n}").replaceAll("=\\d+(?=&|$)", "={n}");
    }

    private void valor(int nivel, String clave) {
        char c = s.charAt(i);
        switch (c) {
            case '{' -> objeto(nivel, "_links".equals(clave));
            case '[' -> lista(nivel, "errores".equals(clave));
            case '"' -> out.append("path".equals(clave) ? ruta(cadena()) : mascaraTexto(cadena()));
            default -> {
                int ini = i;
                while (i < s.length() && ",}] \t\r\n".indexOf(s.charAt(i)) < 0) i++;
                String literal = s.substring(ini, i);
                if (!literal.matches("true|false|null|-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?")) {
                    throw new IllegalArgumentException("literal: " + literal);
                }
                boolean entero = literal.matches("-?\\d+");
                out.append(entero && clave != null && CLAVE_ID.matcher(clave).matches() ? "\"<id>\"" : literal);
            }
        }
    }

    /** Los enlaces de /actuator ({@code _links}) se ordenan: Spring no garantiza su orden y no los usa ninguna app. */
    private void objeto(int nivel, boolean ordenar) {
        i++;
        espacios();
        if (s.charAt(i) == '}') {
            i++;
            out.append("{}");
            return;
        }
        List<String> campos = new ArrayList<>();
        while (true) {
            espacios();
            String clave = cadena();
            espacios();
            esperar(':');
            espacios();
            int marca = out.length();
            sangria(nivel + 1);
            out.append(clave).append(": ");
            valor(nivel + 1, clave.substring(1, clave.length() - 1));
            campos.add(out.substring(marca));
            out.setLength(marca);
            espacios();
            if (s.charAt(i) == ',') {
                i++;
                continue;
            }
            esperar('}');
            break;
        }
        if (ordenar) Collections.sort(campos);
        out.append("{\n").append(String.join(",\n", campos)).append('\n');
        sangria(nivel);
        out.append('}');
    }

    /** Los errores por campo se ordenan: el validador no garantiza el orden y la app los busca por campo. */
    private void lista(int nivel, boolean ordenar) {
        i++;
        espacios();
        if (s.charAt(i) == ']') {
            i++;
            out.append("[]");
            return;
        }
        List<String> elementos = new ArrayList<>();
        while (true) {
            espacios();
            int marca = out.length();
            sangria(nivel + 1);
            valor(nivel + 1, null);
            elementos.add(out.substring(marca));
            out.setLength(marca);
            espacios();
            if (s.charAt(i) == ',') {
                i++;
                continue;
            }
            esperar(']');
            break;
        }
        if (ordenar) Collections.sort(elementos);
        out.append("[\n").append(String.join(",\n", elementos)).append('\n');
        sangria(nivel);
        out.append(']');
    }

    /** Devuelve la cadena tal cual viene escrita, con comillas y escapes. */
    private String cadena() {
        int ini = i;
        esperar('"');
        while (s.charAt(i) != '"') {
            if (s.charAt(i) == '\\') i++;
            i++;
        }
        i++;
        return s.substring(ini, i);
    }

    private static String mascaraTexto(String literal) {
        String v = literal.substring(1, literal.length() - 1);
        if (JWT.matcher(v).matches()) return "\"<jwt>\"";
        // Huellas (SHA-256 de datos que incluyen ids) e ids dentro de JSON incrustado en un texto.
        if (SHA256.matcher(v).matches()) return "\"<sha256>\"";
        if (ID_EN_TEXTO.matcher(literal).find()) literal = ID_EN_TEXTO.matcher(literal).replaceAll("$1<id>");
        if (CODIGO.matcher(v).matches()) return "\"<codigo XXXX-XXXX-XXXX>\"";
        Matcher es = FECHA_HORA_ES.matcher(v);
        if (es.matches() && es.group(1).equals(java.time.LocalDate.now().format(DateTimeFormatter.ofPattern("d/M/yyyy")))) {
            return "\"<ahora d/M/yyyy HH:mm>\"";
        }
        Matcher m = FECHA_HORA.matcher(v);
        if (m.matches() && esAhora(v, m)) {
            String forma = m.group(1).replaceAll("\\d", "d") + "T" + m.group(2).replaceAll("\\d", "d")
                    + (m.group(3) != null ? ".f" : "")
                    + (m.group(4) == null ? "" : m.group(4).equals("Z") ? "Z" : "+hh:mm");
            return "\"<ahora " + forma + ">\"";
        }
        return literal;
    }

    /** Fecha-hora a menos de 10 días de ahora: la ha puesto el servidor (creación, caducidad de invitaciones). */
    private static boolean esAhora(String v, Matcher m) {
        try {
            Instant t;
            if (m.group(4) != null) {
                t = OffsetDateTime.parse(m.group(4).equals("Z") ? v.replace("Z", "+00:00") : v).toInstant();
            } else {
                String base = m.group(2).length() == 5 ? v.replaceFirst("T(\\d{2}:\\d{2})", "T$1:00") : v;
                t = LocalDateTime.parse(base).atZone(ZoneId.systemDefault()).toInstant();
            }
            return Duration.between(t, Instant.now()).abs().compareTo(Duration.ofDays(10)) < 0;
        } catch (RuntimeException e) {
            return false;
        }
    }

    private void espacios() {
        while (i < s.length() && " \t\r\n".indexOf(s.charAt(i)) >= 0) i++;
    }

    private void esperar(char c) {
        if (s.charAt(i) != c) throw new IllegalArgumentException("se esperaba " + c + " en " + i);
        i++;
    }

    private void sangria(int nivel) {
        out.append("  ".repeat(nivel));
    }
}
