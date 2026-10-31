package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.MensajeService;
import com.gestionap.api.web.dto.MensajeDtos.Conversacion;
import com.gestionap.api.web.dto.MensajeDtos.MensajeRequest;
import com.gestionap.api.web.dto.MensajeDtos.MensajeResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Mensajes", description = "Propietario ↔ inquilino, dentro de un contrato o de una de sus incidencias")
@RestController
@RequestMapping("/api")
public class MensajeController {

    private final MensajeService mensajes;

    public MensajeController(MensajeService mensajes) {
        this.mensajes = mensajes;
    }

    @Operation(summary = "Conversaciones de mis contratos, la más reciente primero")
    @GetMapping("/conversaciones")
    public List<Conversacion> conversaciones(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return mensajes.conversaciones(actor);
    }

    @Operation(summary = "Mensajes del contrato (o de una incidencia suya); los marca leídos")
    @GetMapping("/contratos/{id}/mensajes")
    public List<MensajeResponse> hilo(@PathVariable Integer id, @RequestParam(required = false) Integer incidencia,
                                      @AuthenticationPrincipal UsuarioAutenticado actor) {
        return mensajes.hilo(id, incidencia, actor);
    }

    @PostMapping("/contratos/{id}/mensajes")
    @ResponseStatus(HttpStatus.CREATED)
    public MensajeResponse enviar(@PathVariable Integer id, @Valid @RequestBody MensajeRequest req,
                                  @AuthenticationPrincipal UsuarioAutenticado actor) {
        return mensajes.enviar(id, req, actor);
    }

    @Operation(summary = "Mensajes sobre una incidencia (en el contrato de quien la comunicó)")
    @GetMapping("/incidencias/{id}/mensajes")
    public List<MensajeResponse> hiloIncidencia(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return mensajes.hilo(mensajes.contratoDeIncidencia(id, actor), id, actor);
    }

    @PostMapping("/incidencias/{id}/mensajes")
    @ResponseStatus(HttpStatus.CREATED)
    public MensajeResponse enviarIncidencia(@PathVariable Integer id, @Valid @RequestBody MensajeRequest req,
                                            @AuthenticationPrincipal UsuarioAutenticado actor) {
        return mensajes.enviar(mensajes.contratoDeIncidencia(id, actor), new MensajeRequest(req.texto(), id), actor);
    }
}
