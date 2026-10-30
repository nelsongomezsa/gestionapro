package com.gestionap.api.service;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.MetodoPago;
import com.gestionap.api.domain.Pago;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.PagoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.ContratoResponse;
import com.gestionap.api.web.dto.PagoRequest;
import com.gestionap.api.web.dto.PagoResponse;
import com.gestionap.api.web.dto.PisoBreve;
import com.gestionap.api.web.dto.ResumenPagosResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/** Pagos (PagosController + PagoDAO del escritorio). */
@Service
public class PagoService {

    private final PagoRepository pagos;
    private final ContratoRepository contratos;
    private final ContratoService contratoService;
    private final ControlAcceso acceso;
    private final ActividadService actividad;

    public PagoService(PagoRepository pagos, ContratoRepository contratos, ContratoService contratoService,
                       ControlAcceso acceso, ActividadService actividad) {
        this.pagos = pagos;
        this.contratos = contratos;
        this.contratoService = contratoService;
        this.acceso = acceso;
        this.actividad = actividad;
    }

    /** Lista, opcionalmente de un mes y de un inquilino. */
    @Transactional(readOnly = true)
    public List<PagoResponse> listar(YearMonth mes, Integer idInquilino, UsuarioAutenticado actor) {
        var alcance = acceso.alcance(actor);
        Integer inquilino = alcance.idInquilino() != null ? alcance.idInquilino() : idInquilino;
        return pagos.buscar(alcance.idPropietario(), inquilino,
                        mes == null ? null : mes.atDay(1), mes == null ? null : mes.atEndOfMonth())
                .stream().map(PagoResponse::de).toList();
    }

    /**
     * Esperado, cobrado y pendiente del mes. Un contrato está pendiente si estuvo vigente en
     * algún momento del mes y no tiene ningún pago en él (el mismo criterio que el aviso
     * "Pago pendiente este mes" del escritorio, aplicado a cualquier mes).
     */
    @Transactional(readOnly = true)
    public ResumenPagosResponse resumen(YearMonth mes, UsuarioAutenticado actor) {
        var alcance = acceso.alcance(actor);
        LocalDate inicio = mes.atDay(1);
        LocalDate fin = mes.atEndOfMonth();
        List<Contrato> vigentes = contratos.buscar(alcance.idPropietario(), alcance.idInquilino(), null).stream()
                .filter(c -> !c.getFechaInicio().isAfter(fin) && !c.getFechaFin().isBefore(inicio))
                .toList();
        List<Pago> delMes = pagos.buscar(alcance.idPropietario(), alcance.idInquilino(), inicio, fin);
        Set<Integer> conPago = delMes.stream().map(p -> p.getContrato().getId()).collect(Collectors.toSet());

        List<ResumenPagosResponse.Pendiente> pendientes = vigentes.stream()
                .filter(c -> !conPago.contains(c.getId()))
                .map(c -> new ResumenPagosResponse.Pendiente(c.getId(),
                        new ContratoResponse.InquilinoBreve(c.getInquilino().getId(), c.getInquilino().getNombreCompleto(),
                                c.getInquilino().getDni(), c.getInquilino().getTelefono(), c.getInquilino().getEmail()),
                        c.getHabitacion().getNumero(), PisoBreve.de(c.getHabitacion().getPiso()), c.getPrecioMensual()))
                .toList();

        return new ResumenPagosResponse(mes.toString(), Textos.mes(mes),
                suma(vigentes.stream().map(Contrato::getPrecioMensual).toList()),
                suma(delMes.stream().map(Pago::getCantidad).toList()),
                suma(pendientes.stream().map(ResumenPagosResponse.Pendiente::importe).toList()),
                delMes.size(), pendientes);
    }

    /** Como en el escritorio, solo para contratos activos. */
    @Transactional
    public PagoResponse registrar(PagoRequest req, UsuarioAutenticado actor) {
        Contrato c = contratoService.cargarVisible(req.idContrato(), actor);
        if (!c.estaActivoEn(LocalDate.now())) {
            throw ApiException.conflicto("CONTRATO_NO_ACTIVO", "Solo se pueden registrar pagos de contratos activos");
        }
        Pago p = new Pago();
        p.setContrato(c);
        p.setCantidad(req.cantidad());
        p.setMetodoPago(req.metodoPago() != null ? req.metodoPago() : MetodoPago.transferencia);
        p.setFechaPago(req.fechaPago());
        pagos.save(p);
        actividad.registrar(actor.id(), "REGISTRAR_PAGO",
                c.getInquilino().getNombreCompleto() + " · " + req.cantidad().toPlainString() + " €");
        return PagoResponse.de(p);
    }

    @Transactional
    public void borrar(Integer id, UsuarioAutenticado actor) {
        Pago p = pagos.findConPisoById(id)
                .filter(x -> acceso.puedeVerPiso(x.getContrato().getHabitacion().getPiso(), actor))
                .orElseThrow(() -> ApiException.noEncontrado("Pago"));
        pagos.delete(p);
        actividad.registrar(actor.id(), "BORRAR_PAGO",
                "Pago #" + id + " · " + p.getCantidad().toPlainString() + " € · " + p.getFechaPago());
    }

    private static BigDecimal suma(List<BigDecimal> importes) {
        return importes.stream().reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
