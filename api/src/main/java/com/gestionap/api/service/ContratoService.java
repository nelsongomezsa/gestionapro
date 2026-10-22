package com.gestionap.api.service;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.Usuario;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ContratoService {

    public record Pdf(String nombreArchivo, byte[] contenido) {}

    private final ContratoRepository contratos;
    private final ContratoPdfGenerator generador;

    public ContratoService(ContratoRepository contratos, ContratoPdfGenerator generador) {
        this.contratos = contratos;
        this.generador = generador;
    }

    /**
     * PDF del contrato. Pueden pedirlo el ADMIN, el propietario del piso y el
     * inquilino del propio contrato; a cualquier otro se le responde 404.
     */
    @Transactional(readOnly = true)
    public Pdf pdf(Integer idContrato, UsuarioAutenticado actor) {
        Contrato c = contratos.findConDetallesById(idContrato)
                .orElseThrow(() -> ApiException.noEncontrado("Contrato"));
        if (!puedeVer(c, actor)) throw ApiException.noEncontrado("Contrato");

        var piso = c.getHabitacion().getPiso();
        Usuario propietario = piso.getPropietario();
        var datos = new ContratoPdfGenerator.DatosContrato(
                c.getId(),
                propietario.getNombre(),
                propietario.getDni(),
                c.getInquilino().getNombreCompleto(),
                c.getInquilino().getDni(),
                piso.getDireccion(),
                piso.getCiudad().getNombre(),
                c.getHabitacion().getNumero(),
                c.getFechaInicio(),
                c.getFechaFin(),
                c.getPrecioMensual());
        return new Pdf(generador.nombreArchivo(datos), generador.generar(datos));
    }

    private static boolean puedeVer(Contrato c, UsuarioAutenticado actor) {
        return switch (actor.rol()) {
            case ADMIN -> true;
            case PROPIETARIO -> c.getHabitacion().getPiso().getPropietario().getId().equals(actor.id());
            case INQUILINO -> c.getInquilino().getUsuario() != null
                    && c.getInquilino().getUsuario().getId().equals(actor.id());
        };
    }
}
