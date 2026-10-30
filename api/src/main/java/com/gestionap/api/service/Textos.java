package com.gestionap.api.service;

import java.math.BigDecimal;
import java.math.BigInteger;
import java.text.NumberFormat;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.format.TextStyle;
import java.util.Locale;
import java.util.regex.Pattern;

/** Utilidades de texto en español independientes del idioma del servidor. */
public final class Textos {

    private Textos() {}

    public static final Locale ES = Locale.of("es", "ES");

    private static final Pattern IBAN = Pattern.compile("[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}");

    /**
     * Fecha y hora con su zona. Las columnas DATETIME de la BD (NOW() de MariaDB) y
     * LocalDateTime.now() van en la hora local del servidor; enviarlas sin zona hacía que el
     * móvil las leyera como hora de Madrid (en un servidor en UTC+10, «dentro de 9 horas»).
     */
    public static OffsetDateTime conZona(LocalDateTime fecha) {
        return fecha == null ? null : fecha.atZone(ZoneId.systemDefault()).toOffsetDateTime();
    }

    /** "octubre 2026". El escritorio usaba DATE_FORMAT/MMMM, que depende del idioma del servidor. */
    /** 1.234,50 € */
    public static String euros(BigDecimal importe) {
        return NumberFormat.getCurrencyInstance(ES).format(importe);
    }

    public static String mes(YearMonth mes) {
        return mes.getMonth().getDisplayName(TextStyle.FULL, ES) + " " + mes.getYear();
    }

    /** "oct" (para ejes de gráficos). */
    public static String mesCorto(YearMonth mes) {
        return mes.getMonth().getDisplayName(TextStyle.SHORT, ES).replace(".", "");
    }

    /** Quita espacios y pasa a mayúsculas: "es91 2100 0418 4502 0005 1332" → "ES9121000418450200051332". */
    public static String normalizarIban(String iban) {
        return iban.replaceAll("\\s", "").toUpperCase(Locale.ROOT);
    }

    /** Formato y dígitos de control (ISO 13616, módulo 97). Espera el IBAN normalizado. */
    public static boolean ibanValido(String iban) {
        if (!IBAN.matcher(iban).matches()) return false;
        String reordenado = iban.substring(4) + iban.substring(0, 4);
        StringBuilder digitos = new StringBuilder();
        for (char c : reordenado.toCharArray()) {
            digitos.append(Character.isLetter(c) ? String.valueOf(c - 'A' + 10) : String.valueOf(c));
        }
        return new BigInteger(digitos.toString()).mod(BigInteger.valueOf(97)).intValue() == 1;
    }

    /** "ES91 2100 0418 4502 0005 1332". */
    public static String ibanLegible(String iban) {
        return iban.replaceAll("(.{4})(?!$)", "$1 ");
    }
}
