package com.gestionap.api.service;

import com.gestionap.api.web.ApiException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.UUID;

/**
 * Facturas y fotos en disco (gestionap.archivos.dir), no en la base compartida con el escritorio.
 * Se aceptan JPEG, PNG, HEIC y PDF de hasta 10 MB, comprobando la cabecera real del archivo (no
 * el tipo que diga el cliente). El nombre en disco es aleatorio: nunca se usa el del cliente.
 */
@Service
public class ArchivoService {

    public static final long MAXIMO = 10L * 1024 * 1024;

    public record Guardado(String ruta, String tipo) {}

    public record Contenido(byte[] datos, String tipo) {}

    private final Path raiz;

    public ArchivoService(@Value("${gestionap.archivos.dir:${user.home}/gestionap-archivos}") String dir) {
        this.raiz = Path.of(dir).toAbsolutePath().normalize();
    }

    /** Guarda el archivo en carpeta/aaaa/uuid.ext y devuelve su ruta relativa y su tipo. */
    public Guardado guardar(String carpeta, MultipartFile archivo) {
        if (archivo == null || archivo.isEmpty()) throw ApiException.badRequest("ARCHIVO_VACIO", "No se ha enviado ningún archivo");
        if (archivo.getSize() > MAXIMO) throw ApiException.badRequest("ARCHIVO_GRANDE", "El archivo supera los 10 MB");
        try {
            byte[] datos = archivo.getBytes();
            String tipo = tipoReal(datos);
            if (tipo == null) throw ApiException.badRequest("TIPO_NO_ADMITIDO", "Solo fotos (JPEG, PNG, HEIC) o PDF");
            if (!completo(datos, tipo)) throw ApiException.badRequest("ARCHIVO_DANADO", "El archivo está dañado o incompleto");
            String ext = switch (tipo) {
                case "image/jpeg" -> "jpg";
                case "image/png" -> "png";
                case "image/heic" -> "heic";
                default -> "pdf";
            };
            String relativa = carpeta + "/" + java.time.Year.now() + "/" + UUID.randomUUID() + "." + ext;
            Path destino = resolver(relativa);
            Files.createDirectories(destino.getParent());
            Files.write(destino, datos);
            return new Guardado(relativa, tipo);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    public Contenido leer(String relativa, String tipo) {
        try {
            return new Contenido(Files.readAllBytes(resolver(relativa)), tipo);
        } catch (IOException e) {
            throw ApiException.noEncontrado("Archivo");
        }
    }

    public void borrar(String relativa) {
        if (relativa == null) return;
        try {
            Files.deleteIfExists(resolver(relativa));
        } catch (IOException ignorada) {
            // Un archivo que no se puede borrar no impide borrar su registro.
        }
    }

    /** Siempre dentro de la carpeta raíz (sin "../"). */
    private Path resolver(String relativa) {
        Path p = raiz.resolve(relativa).normalize();
        if (!p.startsWith(raiz)) throw ApiException.badRequest("RUTA_NO_VALIDA", "Ruta no válida");
        return p;
    }

    /** JPEG y PNG se decodifican enteros; un PDF debe terminar con su marca %%EOF. HEIC no se puede decodificar en Java. */
    static boolean completo(byte[] d, String tipo) {
        try {
            return switch (tipo) {
                case "image/jpeg", "image/png" -> javax.imageio.ImageIO.read(new java.io.ByteArrayInputStream(d)) != null;
                case "application/pdf" -> new String(d, Math.max(0, d.length - 1024), Math.min(1024, d.length),
                        java.nio.charset.StandardCharsets.ISO_8859_1).contains("%%EOF");
                default -> true;
            };
        } catch (IOException e) {
            return false;
        }
    }

    /** Tipo por los primeros bytes (firma del formato), o null si no es uno admitido. */
    static String tipoReal(byte[] d) {
        if (empieza(d, 0xFF, 0xD8, 0xFF)) return "image/jpeg";
        if (empieza(d, 0x89, 'P', 'N', 'G')) return "image/png";
        if (empieza(d, '%', 'P', 'D', 'F')) return "application/pdf";
        // HEIC: "ftyp" en el byte 4 y una marca heic/heix/mif1.
        if (d.length > 12 && d[4] == 'f' && d[5] == 't' && d[6] == 'y' && d[7] == 'p') {
            String marca = new String(Arrays.copyOfRange(d, 8, 12));
            if (marca.startsWith("hei") || marca.equals("mif1") || marca.equals("msf1")) return "image/heic";
        }
        return null;
    }

    private static boolean empieza(byte[] d, int... firma) {
        if (d.length < firma.length) return false;
        for (int i = 0; i < firma.length; i++) if ((d[i] & 0xFF) != firma[i]) return false;
        return true;
    }
}
