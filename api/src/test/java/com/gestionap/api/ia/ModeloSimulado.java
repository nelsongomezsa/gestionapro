package com.gestionap.api.ia;

import com.gestionap.api.service.ia.ModeloIA;
import com.gestionap.api.web.dto.AsistenteDtos.ClasificacionIncidencia;
import com.gestionap.api.web.dto.AsistenteDtos.PropuestaGasto;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

/**
 * Modelo simulado para los tests (gestionap.ia.simulado=true): no llama a ninguna API. Cada test
 * programa las herramientas que "pide" el modelo; la respuesta junta lo que devolvieron, así se
 * comprueba que se ejecutan con los permisos del usuario y que las acciones solo se proponen.
 */
@Component
@ConditionalOnProperty(name = "gestionap.ia.simulado", havingValue = "true")
public class ModeloSimulado implements ModeloIA {

    public boolean disponible = true;
    public final List<Llamada> planificadas = new ArrayList<>();
    public final List<Resultado> resultados = new ArrayList<>();
    public String instruccionesRecibidas;
    public Object extraccion;
    /** Si no es null, la próxima llamada falla como fallaría la API (429, 5xx...). */
    public RuntimeException fallo;

    public void reiniciar() {
        disponible = true;
        planificadas.clear();
        resultados.clear();
        instruccionesRecibidas = null;
        extraccion = null;
        fallo = null;
    }

    @Override
    public boolean disponible() {
        return disponible;
    }

    @Override
    public Respuesta conversar(String instrucciones, List<Turno> historial, String mensaje, List<Herramienta> herramientas,
                               Ejecutor ejecutor) {
        if (fallo != null) throw fallo;
        instruccionesRecibidas = instrucciones;
        StringBuilder texto = new StringBuilder("Respuesta simulada a: ").append(mensaje);
        for (Llamada l : planificadas) {
            if (herramientas.stream().noneMatch(h -> h.nombre().equals(l.herramienta()))) {
                throw new IllegalStateException("Herramienta no declarada: " + l.herramienta());
            }
            Resultado r = ejecutor.ejecutar(l);
            resultados.add(r);
            texto.append("\n").append(l.herramienta()).append(r.error() ? " [error] " : ": ").append(r.contenido());
        }
        return new Respuesta(texto.toString(), false);
    }

    @Override
    @SuppressWarnings("unchecked")
    public <T> T extraer(String instrucciones, String texto, byte[] imagen, String tipoImagen, Class<T> formato) {
        if (extraccion != null) return (T) extraccion;
        if (formato == ClasificacionIncidencia.class) {
            return (T) new ClasificacionIncidencia("FONTANERIA", "ALTA", "Hay una fuga de agua");
        }
        if (formato == PropuestaGasto.class) {
            return (T) new PropuestaGasto("Fontanería López", "Reparación de la caldera", "2026-10-12", 145.20, "REPARACION", "");
        }
        throw new IllegalArgumentException("Formato no simulado: " + formato);
    }
}
