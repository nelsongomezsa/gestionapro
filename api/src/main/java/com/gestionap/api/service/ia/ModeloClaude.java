package com.gestionap.api.service.ia;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.core.JsonValue;
import com.anthropic.errors.AnthropicException;
import com.anthropic.errors.RateLimitException;
import com.anthropic.errors.UnauthorizedException;
import com.anthropic.models.messages.Base64ImageSource;
import com.anthropic.models.messages.ContentBlock;
import com.anthropic.models.messages.ContentBlockParam;
import com.anthropic.models.messages.Message;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.OutputConfig;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.StructuredMessageCreateParams;
import com.anthropic.models.messages.TextBlock;
import com.anthropic.models.messages.Tool;
import com.anthropic.models.messages.ToolResultBlockParam;
import com.anthropic.models.messages.ToolUseBlock;
import com.fasterxml.jackson.core.type.TypeReference;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * El asistente con la API de Claude (SDK oficial de Java). La clave se lee SOLO de la variable
 * de entorno ANTHROPIC_API_KEY del servidor; sin ella el asistente queda desactivado.
 *
 * - Modelo: Claude Haiku 5.5 por defecto, el más económico (variable ASISTENTE_MODELO para cambiarlo).
 * - Bucle de herramientas propio: las herramientas son nuestras (servicios con los permisos del
 *   usuario); cada respuesta del modelo se devuelve entera en el historial, con sus bloques de
 *   pensamiento, como pide la API.
 * - Fallback del servidor ante un rechazo de los clasificadores de seguridad
 *   ("server-side-fallback-2026-07-01", modo "default") solo en los modelos que lo admiten (Haiku 5.5 no);
 *   si se rechaza, se dice al usuario.
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "gestionap.ia.simulado", havingValue = "false", matchIfMissing = true)
public class ModeloClaude implements ModeloIA {

    private static final int MAX_VUELTAS = 8;

    private final String modelo;
    private final AnthropicClient cliente;

    /** Modelos que aceptan el fallback del servidor ante un rechazo (Claude API). */
    private static final java.util.Set<String> CON_FALLBACK = java.util.Set.of(
            "claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5");

    public ModeloClaude(@Value("${gestionap.ia.modelo:claude-haiku-5-5}") String modelo) {
        this.modelo = modelo;
        String clave = System.getenv("ANTHROPIC_API_KEY");
        this.cliente = clave == null || clave.isBlank() ? null : AnthropicOkHttpClient.fromEnv();
        log.info(cliente == null ? "Asistente desactivado: falta ANTHROPIC_API_KEY" : "Asistente activo con el modelo {}", modelo);
    }

    @Override
    public boolean disponible() {
        return cliente != null;
    }

    @Override
    public Respuesta conversar(String instrucciones, List<Turno> historial, String mensaje, List<Herramienta> herramientas,
                               Ejecutor ejecutor) {
        MessageCreateParams.Builder peticion = MessageCreateParams.builder()
                .model(modelo)
                .maxTokens(16000L)
                .system(instrucciones)
                // Preguntas de gestión: esfuerzo medio basta y responde antes.
                .outputConfig(OutputConfig.builder().effort(OutputConfig.Effort.MEDIUM).build());
        if (CON_FALLBACK.contains(modelo)) {
            peticion.putAdditionalHeader("anthropic-beta", "server-side-fallback-2026-07-01")
                    .putAdditionalBodyProperty("fallbacks", JsonValue.from("default"));
        }
        herramientas.forEach(h -> peticion.addTool(herramienta(h)));
        for (Turno t : historial) {
            if (t.delUsuario()) peticion.addUserMessage(t.texto());
            else peticion.addAssistantMessage(t.texto());
        }
        peticion.addUserMessage(mensaje);

        for (int vuelta = 0; vuelta < MAX_VUELTAS; vuelta++) {
            Message respuesta = llamar(() -> cliente.messages().create(peticion.build()));
            StopReason motivo = respuesta.stopReason().orElse(StopReason.END_TURN);
            if (motivo.equals(StopReason.REFUSAL)) {
                return new Respuesta("No puedo ayudarte con esa petición.", true);
            }
            // La respuesta entera (también el pensamiento) vuelve al historial sin tocarla.
            peticion.addMessage(respuesta);
            List<ToolUseBlock> llamadas = respuesta.content().stream()
                    .flatMap(b -> b.toolUse().stream()).toList();
            if (llamadas.isEmpty()) {
                return new Respuesta(texto(respuesta.content()), false);
            }
            List<ContentBlockParam> resultados = new ArrayList<>();
            for (ToolUseBlock llamada : llamadas) {
                Resultado r;
                try {
                    Map<String, Object> argumentos = llamada._input().convert(new TypeReference<Map<String, Object>>() {});
                    r = ejecutor.ejecutar(new Llamada(llamada.name(), argumentos == null ? Map.of() : argumentos));
                } catch (RuntimeException e) {
                    r = new Resultado("No se pudo ejecutar: " + e.getMessage(), true);
                }
                resultados.add(ContentBlockParam.ofToolResult(ToolResultBlockParam.builder()
                        .toolUseId(llamada.id())
                        .content(r.contenido())
                        .isError(r.error())
                        .build()));
            }
            // Todos los resultados en un solo mensaje del usuario.
            peticion.addUserMessageOfContentBlockParams(resultados);
        }
        return new Respuesta("He necesitado demasiados pasos para responder. Prueba con una pregunta más concreta.", false);
    }

    @Override
    public <T> T extraer(String instrucciones, String texto, byte[] imagen, String tipoImagen, Class<T> formato) {
        List<ContentBlockParam> contenido = new ArrayList<>();
        if (imagen != null) {
            contenido.add(ContentBlockParam.ofImage(Base64ImageSource.builder()
                    .data(Base64.getEncoder().encodeToString(imagen))
                    .mediaType("image/png".equals(tipoImagen) ? Base64ImageSource.MediaType.IMAGE_PNG
                            : Base64ImageSource.MediaType.IMAGE_JPEG)
                    .build()));
        }
        contenido.add(ContentBlockParam.ofText(texto));
        StructuredMessageCreateParams<T> peticion = MessageCreateParams.builder()
                .model(modelo)
                .maxTokens(4000L)
                .system(instrucciones)
                .outputConfig(formato)
                .addUserMessageOfContentBlockParams(contenido)
                .build();
        return llamar(() -> cliente.messages().create(peticion)).content().stream()
                .flatMap(b -> b.text().stream())
                .map(t -> t.text())
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("El modelo no devolvió datos"));
    }

    /**
     * Traduce los errores del SDK (que ya reintenta 429, 5xx y fallos de red) a un mensaje claro.
     * Del más concreto al más general.
     */
    private static <T> T llamar(java.util.function.Supplier<T> llamada) {
        try {
            return llamada.get();
        } catch (RateLimitException e) {
            throw new Fallo("El servicio de IA está recibiendo demasiadas consultas. Prueba en un minuto.", e);
        } catch (UnauthorizedException e) {
            log.error("La clave de la API de Claude no es válida");
            throw new Fallo("La clave de la API de Claude del servidor no es válida.", e);
        } catch (AnthropicException e) {
            log.warn("Fallo de la API de Claude: {}", e.getMessage());
            throw new Fallo("El asistente no responde ahora mismo. Prueba en unos minutos.", e);
        }
    }

    private static Tool herramienta(Herramienta h) {
        Tool.InputSchema.Properties.Builder propiedades = Tool.InputSchema.Properties.builder();
        h.propiedades().forEach((nombre, esquema) -> propiedades.putAdditionalProperty(nombre, JsonValue.from(esquema)));
        return Tool.builder()
                .name(h.nombre())
                .description(h.descripcion())
                .inputSchema(Tool.InputSchema.builder()
                        .properties(propiedades.build())
                        .required(h.obligatorias())
                        .build())
                .build();
    }

    private static String texto(List<ContentBlock> bloques) {
        return bloques.stream().flatMap(b -> b.text().stream()).map(TextBlock::text).collect(Collectors.joining("\n")).trim();
    }
}
