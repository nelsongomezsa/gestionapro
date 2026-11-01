package com.gestionap.api.service;

import com.gestionap.api.domain.Rol;
import com.gestionap.api.domain.Usuario;
import com.gestionap.api.repository.DispositivoRepository;
import com.gestionap.api.repository.InquilinoRepository;
import com.gestionap.api.repository.UsuarioRepository;
import com.gestionap.api.security.LimiteIntentos;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.UsuarioDtos.EliminarCuentaRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Eliminar la propia cuenta (obligatorio en el App Store). Borrado lógico: se anonimizan los datos
 * personales del usuario (nombre, email, DNI, IBAN) y se invalida su contraseña; se conservan los
 * pisos, contratos, pagos y recibos que la ley obliga a guardar, y la ficha del inquilino (que es del
 * propietario) queda sin cuenta enlazada. El token deja de valer al quedar la cuenta inactiva.
 */
@Service
public class CuentaService {

    private final UsuarioRepository usuarios;
    private final InquilinoRepository inquilinos;
    private final DispositivoRepository dispositivos;
    private final PasswordEncoder encoder;
    private final LimiteIntentos limites;
    private final ActividadService actividad;

    public CuentaService(UsuarioRepository usuarios, InquilinoRepository inquilinos, DispositivoRepository dispositivos,
                         PasswordEncoder encoder, LimiteIntentos limites, ActividadService actividad) {
        this.usuarios = usuarios;
        this.inquilinos = inquilinos;
        this.dispositivos = dispositivos;
        this.encoder = encoder;
        this.limites = limites;
        this.actividad = actividad;
    }

    @Transactional
    public void eliminar(EliminarCuentaRequest req, UsuarioAutenticado actor) {
        limites.comprobarUsuario(actor.id());
        Usuario u = usuarios.findById(actor.id()).orElseThrow(() -> ApiException.noEncontrado("Usuario"));
        if (!encoder.matches(req.password(), u.getPasswordHash())) {
            limites.falloUsuario(actor.id());
            throw ApiException.badRequest("PASSWORD_INCORRECTA", "La contraseña no es correcta");
        }
        limites.aciertoUsuario(actor.id());
        if (u.getRol() == Rol.ADMIN && usuarios.contarAdminsActivos() <= 1) {
            throw ApiException.conflicto("ULTIMO_ADMIN", "Eres el único administrador: nombra otro antes de eliminar tu cuenta");
        }

        inquilinos.findByUsuarioId(u.getId()).ifPresent(i -> i.setUsuario(null));
        dispositivos.deleteAll(dispositivos.findByIdUsuario(u.getId()));

        u.setNombre("Usuario eliminado");
        u.setEmail("baja-" + u.getId() + "-" + UUID.randomUUID().toString().substring(0, 8) + "@baja.invalid");
        u.setDni(null);
        u.setIban(null);
        u.setPasswordHash(encoder.encode(UUID.randomUUID().toString()));
        u.setActivo(false);
        u.setDebeCambiarPassword(false);
        u.setFechaBaja(LocalDateTime.now());
        // Sin datos personales en el registro de actividad.
        actividad.registrar(u.getId(), "ELIMINAR_CUENTA", "Cuenta eliminada por su titular");
    }
}
