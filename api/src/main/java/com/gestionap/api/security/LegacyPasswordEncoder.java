package com.gestionap.api.security;

import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * BCrypt para todo lo nuevo, pero acepta los hashes SHA-256 hex que aún
 * quedan en Usuarios (mismo criterio que PasswordUtil del escritorio).
 * upgradeEncoding() avisa de que hay que rehashear tras un login correcto.
 */
public class LegacyPasswordEncoder implements PasswordEncoder {

    private final BCryptPasswordEncoder bcrypt = new BCryptPasswordEncoder();

    @Override
    public String encode(CharSequence raw) {
        return bcrypt.encode(raw);
    }

    @Override
    public boolean matches(CharSequence raw, String guardado) {
        if (raw == null || guardado == null) return false;
        if (esBcrypt(guardado)) return bcrypt.matches(raw, guardado);
        byte[] esperado = sha256Hex(raw.toString()).getBytes(StandardCharsets.US_ASCII);
        return MessageDigest.isEqual(esperado, guardado.getBytes(StandardCharsets.US_ASCII));
    }

    @Override
    public boolean upgradeEncoding(String guardado) {
        return !esBcrypt(guardado);
    }

    private static boolean esBcrypt(String hash) {
        return hash != null && hash.startsWith("$2");
    }

    static String sha256Hex(String texto) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256").digest(texto.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 no disponible", e);
        }
    }
}
