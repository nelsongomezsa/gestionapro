package com.gestionap.api.web;

import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.NotificacionService;
import com.gestionap.api.web.dto.NotificacionResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Tag(name = "Notificaciones", description = "Avisos del usuario; se generan al consultarlos, como en el escritorio")
@RestController
@RequestMapping("/api/notificaciones")
public class NotificacionController {

    private final NotificacionService notificaciones;

    public NotificacionController(NotificacionService notificaciones) {
        this.notificaciones = notificaciones;
    }

    @Operation(summary = "Últimos 100 avisos (o solo los no leídos), cada uno con la pantalla a la que lleva")
    @GetMapping
    public List<NotificacionResponse> listar(@RequestParam(defaultValue = "false") boolean soloNoLeidas,
                                             @AuthenticationPrincipal UsuarioAutenticado actor) {
        return notificaciones.listar(soloNoLeidas, actor);
    }

    @Operation(summary = "Número de avisos sin leer (para el contador de la campana)")
    @GetMapping("/no-leidas")
    public Map<String, Long> noLeidas(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return Map.of("total", notificaciones.noLeidas(actor));
    }

    @PostMapping("/{id}/leida")
    public NotificacionResponse marcarLeida(@PathVariable Integer id, @AuthenticationPrincipal UsuarioAutenticado actor) {
        return notificaciones.marcarLeida(id, actor);
    }

    @Operation(summary = "Marca todos como leídos")
    @PostMapping("/leidas")
    public Map<String, Integer> marcarTodas(@AuthenticationPrincipal UsuarioAutenticado actor) {
        return Map.of("marcadas", notificaciones.marcarTodasLeidas(actor));
    }
}
