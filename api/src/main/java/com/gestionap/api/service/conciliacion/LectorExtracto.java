package com.gestionap.api.service.conciliacion;

import com.gestionap.api.web.ApiException;

import java.math.BigDecimal;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.text.Normalizer;

/** Lee movimientos CSV habituales de entidades españolas. */
public class LectorExtracto {

    public record Movimiento(LocalDate fecha, String concepto, BigDecimal importe, BigDecimal saldo) {}

    /** Interpreta formatos bancarios aproximados; conviene probar con extractos reales. */
    public List<Movimiento> leer(byte[] contenido) {
        String csv = decodificar(contenido);
        String[] lineas = csv.split("\\R", -1);
        if (lineas.length > 5001) {
            throw ApiException.badRequest("CSV_DEMASIADAS_LINEAS", "El archivo supera las 5.000 líneas");
        }
        int cabecera = -1;
        char separador = ';';
        List<String> columnas = List.of();
        for (int i = 0; i < lineas.length; i++) {
            char sep = separador(lineas[i]);
            List<String> valores = separar(lineas[i], sep);
            if (indice(valores, "fecha", "f valor", "fecha valor", "fecha operacion", "fecha contable") >= 0
                    && indice(valores, "concepto", "descripcion", "movimiento", "observaciones") >= 0
                    && (indice(valores, "importe", "cantidad", "importe eur") >= 0
                    || (parImportes(valores) != null))) {
                cabecera = i;
                separador = sep;
                columnas = valores;
                break;
            }
        }
        if (cabecera < 0) {
            throw ApiException.badRequest("CSV_CABECERA_INVALIDA", "No se encontró una cabecera válida");
        }
        int f = indice(columnas, "fecha", "f valor", "fecha valor", "fecha operacion", "fecha contable");
        int c = indice(columnas, "concepto", "descripcion", "movimiento", "observaciones");
        int imp = indice(columnas, "importe", "cantidad", "importe eur");
        int[] par = imp < 0 ? parImportes(columnas) : null;
        int saldo = indice(columnas, "saldo", "saldo eur", "saldo disponible");
        List<Movimiento> resultado = new ArrayList<>();
        for (int i = cabecera + 1; i < lineas.length; i++) {
            if (lineas[i].isBlank()) continue;
            List<String> valores = separar(lineas[i], separador);
            try {
                LocalDate fecha = fecha(valores.get(f).trim());
                BigDecimal importe = imp >= 0 ? importe(valores.get(imp))
                        : importe(valores.get(par[1])).subtract(importe(valores.get(par[0])));
                String concepto = valores.get(c).trim();
                BigDecimal saldoValor = saldo >= 0 && saldo < valores.size() && !valores.get(saldo).isBlank()
                        ? importe(valores.get(saldo)) : null;
                resultado.add(new Movimiento(fecha, concepto, importe, saldoValor));
            } catch (IndexOutOfBoundsException | NumberFormatException | DateTimeParseException e) {
                continue;
            }
        }
        return resultado;
    }

    private static String decodificar(byte[] datos) {
        int offset = datos.length >= 3 && (datos[0] & 255) == 239 && (datos[1] & 255) == 187 && (datos[2] & 255) == 191 ? 3 : 0;
        try {
            return StandardCharsets.UTF_8.newDecoder().decode(ByteBuffer.wrap(datos, offset, datos.length - offset)).toString();
        } catch (CharacterCodingException e) {
            return new String(datos, StandardCharsets.ISO_8859_1);
        }
    }

    private static char separador(String linea) {
        int puntoComa = contar(linea, ';');
        int coma = contar(linea, ',');
        int tab = contar(linea, '\t');
        return tab > puntoComa && tab > coma ? '\t' : coma > puntoComa ? ',' : ';';
    }

    private static int contar(String texto, char caracter) {
        return (int) texto.chars().filter(c -> c == caracter).count();
    }

    private static List<String> separar(String linea, char separador) {
        List<String> partes = new ArrayList<>();
        StringBuilder valor = new StringBuilder();
        boolean comillas = false;
        for (int i = 0; i < linea.length(); i++) {
            char actual = linea.charAt(i);
            if (actual == '"') {
                if (comillas && i + 1 < linea.length() && linea.charAt(i + 1) == '"') {
                    valor.append('"');
                    i++;
                } else {
                    comillas = !comillas;
                }
            } else if (actual == separador && !comillas) {
                partes.add(valor.toString().trim());
                valor.setLength(0);
            } else {
                valor.append(actual);
            }
        }
        partes.add(valor.toString().trim());
        return partes;
    }

    private static int indice(List<String> valores, String... alias) {
        for (int i = 0; i < valores.size(); i++) {
            String normal = normalizar(valores.get(i));
            for (String nombre : alias) if (normal.equals(nombre)) return i;
        }
        return -1;
    }

    private static int[] parImportes(List<String> columnas) {
        int cargo = indice(columnas, "cargo", "debe");
        int abono = indice(columnas, "abono", "haber");
        return cargo >= 0 && abono >= 0 ? new int[]{cargo, abono} : null;
    }

    private static String normalizar(String texto) {
        return Normalizer.normalize(texto.toLowerCase(Locale.ROOT).replace('€', ' ').trim(), Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "").replaceAll("[().]", "").replaceAll("\\s+", " ");
    }

    private static LocalDate fecha(String valor) {
        for (DateTimeFormatter formato : List.of(DateTimeFormatter.ofPattern("d/M/uuuu"),
                DateTimeFormatter.ofPattern("d-M-uuuu"), DateTimeFormatter.ISO_LOCAL_DATE)) {
            try {
                return LocalDate.parse(valor, formato);
            } catch (DateTimeParseException ignored) {
            }
        }
        throw new DateTimeParseException("Fecha inválida", valor, 0);
    }

    private static BigDecimal importe(String valor) {
        String limpio = valor.replace("€", "").replace(" ", "").trim();
        if (limpio.isEmpty() || limpio.equals("-")) return BigDecimal.ZERO;
        return new BigDecimal(limpio.replace(".", "").replace(',', '.'));
    }
}
