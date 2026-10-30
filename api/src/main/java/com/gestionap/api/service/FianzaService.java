package com.gestionap.api.service;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.Fianza;
import com.gestionap.api.repository.FianzaRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.DevolucionFianzaRequest;
import com.gestionap.api.web.dto.FianzaRequest;
import com.gestionap.api.web.dto.FianzaResponse;
import com.gestionap.api.web.dto.ResumenFianzasResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;

/** Fianzas por contrato (nuevo en la API: el escritorio no las gestiona). */
@Service
public class FianzaService {

    private final FianzaRepository fianzas;
    private final ContratoService contratos;
    private final ControlAcceso acceso;
    private final ActividadService actividad;

    public FianzaService(FianzaRepository fianzas, ContratoService contratos, ControlAcceso acceso,
                         ActividadService actividad) {
        this.fianzas = fianzas;
        this.contratos = contratos;
        this.acceso = acceso;
        this.actividad = actividad;
    }

    @Transactional(readOnly = true)
    public FianzaResponse obtener(Integer idContrato, UsuarioAutenticado actor) {
        contratos.cargarVisible(idContrato, actor);
        return FianzaResponse.de(fianzas.findByContratoId(idContrato)
                .orElseThrow(() -> ApiException.noEncontrado("Fianza")));
    }

    /** Crea o actualiza la fianza del contrato. */
    @Transactional
    public FianzaResponse guardar(Integer idContrato, FianzaRequest req, UsuarioAutenticado actor) {
        Contrato c = contratos.cargarVisible(idContrato, actor);
        Fianza f = fianzas.bloquearDeContrato(idContrato).orElseGet(() -> {
            Fianza nueva = new Fianza();
            nueva.setContrato(c);
            return nueva;
        });
        // Tras la devolución el importe queda fijo: cambiarlo alteraría lo retenido sin motivo.
        if (f.devuelta() && req.importe().compareTo(f.getImporte()) != 0) {
            throw ApiException.conflicto("FIANZA_YA_DEVUELTA", "La fianza ya está devuelta: su importe no se puede cambiar");
        }
        if (req.fechaCobro() != null && req.fechaDeposito() != null && req.fechaDeposito().isBefore(req.fechaCobro())) {
            throw ApiException.badRequest("FECHA_DEPOSITO_NO_VALIDA", "El depósito no puede ser anterior al cobro");
        }
        f.setImporte(req.importe());
        f.setFechaCobro(req.fechaCobro());
        f.setFechaDeposito(req.fechaDeposito());
        f.setOrganismoDeposito(limpio(req.organismoDeposito()));
        f.setReferenciaDeposito(limpio(req.referenciaDeposito()));
        f.setNotas(limpio(req.notas()));
        fianzas.save(f);
        actividad.registrar(actor.id(), "GUARDAR_FIANZA",
                c.getInquilino().getNombreCompleto() + " · " + req.importe().toPlainString() + " €");
        return FianzaResponse.de(f);
    }

    /** Si se devuelve menos que la fianza, hay que decir por qué (daños, recibos pendientes...). */
    @Transactional
    public FianzaResponse devolver(Integer idContrato, DevolucionFianzaRequest req, UsuarioAutenticado actor) {
        contratos.cargarVisible(idContrato, actor);
        Fianza f = fianzas.bloquearDeContrato(idContrato).orElseThrow(() -> ApiException.noEncontrado("Fianza"));
        if (f.devuelta()) throw ApiException.conflicto("FIANZA_YA_DEVUELTA", "La devolución ya está registrada");
        int frente = req.importeDevuelto().compareTo(f.getImporte());
        if (frente > 0) {
            throw ApiException.badRequest("IMPORTE_DEVOLUCION_NO_VALIDO", "No se puede devolver más que la fianza");
        }
        String motivo = limpio(req.motivoRetencion());
        if (frente < 0 && motivo == null) {
            throw ApiException.badRequest("MOTIVO_RETENCION_OBLIGATORIO", "Indica por qué no se devuelve entera");
        }
        if (f.getFechaCobro() != null && req.fechaDevolucion().isBefore(f.getFechaCobro())) {
            throw ApiException.badRequest("FECHA_DEVOLUCION_NO_VALIDA", "La devolución no puede ser anterior al cobro");
        }
        f.setFechaDevolucion(req.fechaDevolucion());
        f.setImporteDevuelto(req.importeDevuelto());
        f.setMotivoRetencion(frente < 0 ? motivo : null);
        actividad.registrar(actor.id(), "DEVOLVER_FIANZA", f.getContrato().getInquilino().getNombreCompleto()
                + " · " + req.importeDevuelto().toPlainString() + " de " + f.getImporte().toPlainString() + " €");
        return FianzaResponse.de(f);
    }

    @Transactional(readOnly = true)
    public ResumenFianzasResponse listar(UsuarioAutenticado actor) {
        var alcance = acceso.alcance(actor);
        List<FianzaResponse> lista = fianzas.buscar(alcance.idPropietario(), alcance.idInquilino()).stream()
                .map(FianzaResponse::de).toList();
        BigDecimal total = lista.stream().map(FianzaResponse::pendienteDevolver).reduce(BigDecimal.ZERO, BigDecimal::add);
        return new ResumenFianzasResponse(lista, total);
    }

    private static String limpio(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
