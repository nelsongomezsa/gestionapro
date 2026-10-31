package com.gestionap.api.service;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.Pago;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.PagoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.service.conciliacion.LectorExtracto;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.ConciliacionDtos;
import com.gestionap.api.web.dto.PagoRequest;
import com.gestionap.api.web.dto.PagoResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.math.BigDecimal;
import java.text.Normalizer;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/** Analiza movimientos bancarios y registra pagos confirmados por el propietario. */
@Service
public class ConciliacionService {

    private final ContratoRepository contratos;
    private final PagoRepository pagos;
    private final ControlAcceso acceso;
    private final PagoService pagoService;
    private final LectorExtracto lector = new LectorExtracto();

    public ConciliacionService(ContratoRepository contratos, PagoRepository pagos, ControlAcceso acceso,
                               PagoService pagoService) {
        this.contratos = contratos;
        this.pagos = pagos;
        this.acceso = acceso;
        this.pagoService = pagoService;
    }

    /** Propone el contrato más probable para cada ingreso del extracto. */
    @Transactional(readOnly = true)
    public ConciliacionDtos.Analisis analizar(MultipartFile archivo, YearMonth mes, UsuarioAutenticado actor) {
        if (archivo == null || archivo.getSize() > 2 * 1024 * 1024) {
            throw ApiException.badRequest("CSV_TAMANO_INVALIDO", "El archivo no puede superar 2 MB");
        }
        List<LectorExtracto.Movimiento> movimientos;
        try {
            byte[] contenido = archivo.getBytes();
            if (contenido.length > 2 * 1024 * 1024) {
                throw ApiException.badRequest("CSV_TAMANO_INVALIDO", "El archivo no puede superar 2 MB");
            }
            movimientos = lector.leer(contenido);
        } catch (IOException e) {
            throw ApiException.badRequest("CSV_LECTURA", "No se pudo leer el archivo");
        }
        var alcance = acceso.alcance(actor);
        List<Contrato> visibles = contratos.buscar(alcance.idPropietario(), alcance.idInquilino(), null);
        List<ConciliacionDtos.MovimientoAnalizado> propuestas = new ArrayList<>();
        List<ConciliacionDtos.Movimiento> sinPropuesta = new ArrayList<>();
        List<Pago> existentes = pagos.buscar(alcance.idPropietario(), alcance.idInquilino(), null, null);
        for (int indiceMovimiento = 0; indiceMovimiento < movimientos.size(); indiceMovimiento++) {
            LectorExtracto.Movimiento movimiento = movimientos.get(indiceMovimiento);
            if (movimiento.importe().signum() <= 0 || (mes != null && !YearMonth.from(movimiento.fecha()).equals(mes))) continue;
            Contrato mejor = null;
            int mejorPuntuacion = -1;
            for (Contrato contrato : visibles) {
                if (movimiento.fecha().isBefore(contrato.getFechaInicio()) || movimiento.fecha().isAfter(contrato.getFechaFin())) continue;
                int puntuacion = puntuacion(movimiento, contrato);
                if (puntuacion > mejorPuntuacion) {
                    mejor = contrato;
                    mejorPuntuacion = puntuacion;
                }
            }
            var dtoMovimiento = new ConciliacionDtos.Movimiento(movimiento.fecha(), movimiento.concepto(), movimiento.importe(), movimiento.saldo());
            if (mejor == null) {
                sinPropuesta.add(dtoMovimiento);
            } else {
                Contrato contratoPropuesto = mejor;
                boolean registrado = existentes.stream().anyMatch(p -> p.getContrato().getId().equals(contratoPropuesto.getId())
                        && YearMonth.from(p.getFechaPago()).equals(YearMonth.from(movimiento.fecha()))
                        && p.getCantidad().compareTo(movimiento.importe()) == 0);
                var habitacion = mejor.getHabitacion();
                var propuesta = new ConciliacionDtos.Propuesta(mejor.getId(), mejor.getInquilino().getNombreCompleto(),
                        habitacion.getNumero(), habitacion.getPiso().getDireccion(), mejor.getPrecioMensual(), mejorPuntuacion,
                        mejorPuntuacion >= 90 ? "ALTA" : mejorPuntuacion >= 60 ? "MEDIA" : "BAJA",
                        registrado, mejorPuntuacion >= 60 && !registrado);
                propuestas.add(new ConciliacionDtos.MovimientoAnalizado(indiceMovimiento, dtoMovimiento, propuesta));
            }
        }
        return new ConciliacionDtos.Analisis(propuestas, sinPropuesta);
    }

    /** Registra solo los pagos seleccionados explícitamente por el usuario. */
    @Transactional
    public List<PagoResponse> confirmar(List<ConciliacionDtos.Confirmacion> confirmaciones, UsuarioAutenticado actor) {
        if (confirmaciones == null || confirmaciones.isEmpty()) {
            throw ApiException.badRequest("PAGOS_VACIOS", "Selecciona al menos un pago");
        }
        var alcance = acceso.alcance(actor);
        Set<String> claves = new HashSet<>();
        List<Pago> existentes = pagos.buscar(alcance.idPropietario(), alcance.idInquilino(), null, null);
        for (var confirmacion : confirmaciones) {
            String clave = confirmacion.idContrato() + "|" + confirmacion.fecha() + "|" + confirmacion.importe().stripTrailingZeros();
            if (!claves.add(clave)) throw ApiException.conflicto("PAGO_DUPLICADO", "La confirmación contiene pagos duplicados");
            boolean existe = existentes.stream().anyMatch(p -> p.getContrato().getId().equals(confirmacion.idContrato())
                    && p.getFechaPago().equals(confirmacion.fecha()) && p.getCantidad().compareTo(confirmacion.importe()) == 0);
            if (existe) throw ApiException.conflicto("PAGO_DUPLICADO", "Ya existe ese pago");
        }
        List<PagoResponse> creados = new ArrayList<>();
        for (var confirmacion : confirmaciones) {
            creados.add(pagoService.registrar(new PagoRequest(confirmacion.idContrato(), confirmacion.importe(),
                    confirmacion.metodoPago(), confirmacion.fecha()), actor));
        }
        return creados;
    }

    private static int puntuacion(LectorExtracto.Movimiento movimiento, Contrato contrato) {
        int puntos = movimiento.importe().compareTo(contrato.getPrecioMensual()) == 0 ? 50 : 0;
        String concepto = normalizar(movimiento.concepto());
        String completo = normalizar(contrato.getInquilino().getNombreCompleto());
        String apellido = normalizar(contrato.getInquilino().getApellidos());
        if (!completo.isBlank() && concepto.contains(completo)) puntos += 40;
        else if (!apellido.isBlank() && concepto.contains(apellido)) puntos += 20;
        // "hab 1", "hab. 1" o "habitacion 1": un "1" suelto (de una fecha o un importe) no cuenta.
        boolean habitacion = concepto.matches(".*\\bhab(?:itacion|\\.)?\\s*" + contrato.getHabitacion().getNumero() + "\\b.*");
        String direccion = normalizar(contrato.getHabitacion().getPiso().getDireccion());
        if (habitacion || (!direccion.isBlank() && concepto.contains(direccion))) puntos += 10;
        return puntos;
    }

    private static String normalizar(String texto) {
        return Normalizer.normalize(texto.toLowerCase(Locale.ROOT), Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "");
    }
}
