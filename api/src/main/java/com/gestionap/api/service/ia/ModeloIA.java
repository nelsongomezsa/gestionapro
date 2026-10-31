package com.gestionap.api.service.ia;

import java.util.List;
import java.util.Map;

/**
 * El modelo de lenguaje detrás del asistente. Separado del resto para poder simularlo en los
 * tests (sin llamar a la API real) y cambiar de implementación sin tocar el asistente.
 */
public interface ModeloIA {

    /** Turno previo de la conversación (solo texto: lo que se vio en la app). */
    record Turno(boolean delUsuario, String texto) {}

    /** Herramienta que el modelo puede pedir: nombre, para qué sirve y su esquema JSON. */
    record Herramienta(String nombre, String descripcion, Map<String, Object> propiedades, List<String> obligatorias) {}

    /** Lo que el modelo pide ejecutar: herramienta y argumentos ya leídos del JSON. */
    record Llamada(String herramienta, Map<String, Object> argumentos) {}

    /** Resultado de una herramienta para devolvérselo al modelo. */
    record Resultado(String contenido, boolean error) {}

    record Respuesta(String texto, boolean rechazada) {}

    /** Ejecuta las herramientas con los permisos del usuario (el modelo nunca toca la base). */
    @FunctionalInterface
    interface Ejecutor {
        Resultado ejecutar(Llamada llamada);
    }

    /** El servicio del modelo falló (límite, caída, red, clave no válida); el mensaje es para el usuario. */
    class Fallo extends RuntimeException {
        public Fallo(String mensaje, Throwable causa) {
            super(mensaje, causa);
        }
    }

    /** false si falta la clave del servidor: el asistente aparece desactivado. */
    boolean disponible();

    /** Conversa usando herramientas hasta tener una respuesta para el usuario. */
    Respuesta conversar(String instrucciones, List<Turno> historial, String mensaje, List<Herramienta> herramientas,
                        Ejecutor ejecutor);

    /**
     * Extrae datos con un formato fijo (salida estructurada) de un texto y, si se da, una imagen.
     * tipoImagen: image/jpeg o image/png.
     */
    <T> T extraer(String instrucciones, String texto, byte[] imagen, String tipoImagen, Class<T> formato);
}
