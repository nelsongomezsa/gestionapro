package com.gestionap.api.service;

import com.gestionap.api.domain.Invitacion;
import com.gestionap.api.domain.Inquilino;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.InquilinoRepository;
import com.gestionap.api.repository.InvitacionRepository;
import com.gestionap.api.repository.UsuarioRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.InvitacionResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;
import java.util.Locale;

@Service
public class InvitacionService {

    /** Sin 0/O, 1/I/L: el código se teclea a mano en el móvil. 12 caracteres ≈ 59 bits. */
    private static final char[] ALFABETO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".toCharArray();
    private static final int LONGITUD = 12;
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final DateTimeFormatter FMT_FECHA = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

    private final InquilinoRepository inquilinos;
    private final InvitacionRepository invitaciones;
    private final ContratoRepository contratos;
    private final UsuarioRepository usuarios;
    private final EmailService email;
    private final ActividadService actividad;
    private final Duration validez;

    public InvitacionService(InquilinoRepository inquilinos, InvitacionRepository invitaciones,
                             ContratoRepository contratos, UsuarioRepository usuarios,
                             EmailService email, ActividadService actividad,
                             @Value("${gestionap.invitaciones.validez}") Duration validez) {
        this.inquilinos = inquilinos;
        this.invitaciones = invitaciones;
        this.contratos = contratos;
        this.usuarios = usuarios;
        this.email = email;
        this.actividad = actividad;
        this.validez = validez;
    }

    /**
     * Genera un código de un solo uso para que el inquilino cree su cuenta.
     * Un propietario solo puede invitar a inquilinos con contrato en alguno de
     * sus pisos (Inquilinos no tiene dueño propio). Las invitaciones
     * pendientes anteriores del mismo inquilino dejan de valer.
     */
    @Transactional
    public InvitacionResponse generar(Integer idInquilino, UsuarioAutenticado actor) {
        Inquilino inquilino = inquilinos.findById(idInquilino)
                .orElseThrow(() -> ApiException.noEncontrado("Inquilino"));
        if (!actor.esAdmin() && !contratos.inquilinoTieneContratoConPropietario(idInquilino, actor.id())) {
            // 404 y no 403: no se confirma que el inquilino exista a quien no es su propietario.
            throw ApiException.noEncontrado("Inquilino");
        }
        if (inquilino.getUsuario() != null) {
            throw ApiException.conflicto("INQUILINO_YA_REGISTRADO", "Este inquilino ya tiene una cuenta");
        }

        LocalDateTime ahora = LocalDateTime.now();
        invitaciones.caducarPendientes(idInquilino, ahora);

        String codigo = nuevoCodigo();
        Invitacion inv = new Invitacion();
        inv.setCodigoHash(hashCodigo(codigo));
        inv.setInquilino(inquilino);
        inv.setCreador(usuarios.getReferenceById(actor.id()));
        inv.setFechaCreacion(ahora);
        inv.setFechaExpiracion(ahora.plus(validez));
        invitaciones.save(inv);

        actividad.registrar(actor.id(), "INVITAR_INQUILINO",
                "Invitación para " + inquilino.getNombreCompleto() + " (#" + idInquilino + ")");

        boolean enviado = inquilino.getEmail() != null && !inquilino.getEmail().isBlank()
                && email.enviar(inquilino.getEmail(), "Tu invitación a GestionAp",
                        "Hola " + inquilino.getNombre() + ",\n\n"
                                + "Tu código para crear tu cuenta en la app GestionAp es:\n\n    " + codigo + "\n\n"
                                + "Es de un solo uso y caduca el " + inv.getFechaExpiracion().format(FMT_FECHA) + ".\n");

        return new InvitacionResponse(codigo, idInquilino, inv.getFechaExpiracion(), enviado);
    }

    private static String nuevoCodigo() {
        StringBuilder sb = new StringBuilder(LONGITUD + 2);
        for (int i = 0; i < LONGITUD; i++) {
            if (i > 0 && i % 4 == 0) sb.append('-');
            sb.append(ALFABETO[RANDOM.nextInt(ALFABETO.length)]);
        }
        return sb.toString();
    }

    /** Normaliza (mayúsculas, sin guiones ni espacios) y aplica SHA-256: así se guarda y así se busca. */
    static String hashCodigo(String codigo) {
        String normalizado = codigo.replaceAll("[\\s-]", "").toUpperCase(Locale.ROOT);
        try {
            byte[] h = MessageDigest.getInstance("SHA-256").digest(normalizado.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(h);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
