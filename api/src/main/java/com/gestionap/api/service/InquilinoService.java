package com.gestionap.api.service;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.Inquilino;
import com.gestionap.api.domain.Usuario;
import com.gestionap.api.repository.*;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Inquilinos (InquilinosController + InquilinoDAO del escritorio). Un propietario ve los
 * que dio de alta y los que tienen o tuvieron contrato en sus pisos; el admin, todos.
 */
@Service
public class InquilinoService {

    private static final int MAX_PAGOS_FICHA = 24;

    private final InquilinoRepository inquilinos;
    private final ContratoRepository contratos;
    private final PagoRepository pagos;
    private final IncidenciaRepository incidencias;
    private final UsuarioRepository usuarios;
    private final ControlAcceso acceso;
    private final ActividadService actividad;

    public InquilinoService(InquilinoRepository inquilinos, ContratoRepository contratos, PagoRepository pagos,
                            IncidenciaRepository incidencias, UsuarioRepository usuarios, ControlAcceso acceso,
                            ActividadService actividad) {
        this.inquilinos = inquilinos;
        this.contratos = contratos;
        this.pagos = pagos;
        this.incidencias = incidencias;
        this.usuarios = usuarios;
        this.acceso = acceso;
        this.actividad = actividad;
    }

    /** Lista con búsqueda por nombre, apellidos, DNI, teléfono o email (como el escritorio). */
    @Transactional(readOnly = true)
    public List<InquilinoResponse> listar(String texto, UsuarioAutenticado actor) {
        List<Inquilino> lista = inquilinos.visiblesPara(acceso.filtroPropietario(actor));
        if (texto != null && !texto.isBlank()) {
            String t = texto.trim().toLowerCase(Textos.ES);
            lista = lista.stream().filter(i -> contiene(i.getNombreCompleto(), t) || contiene(i.getDni(), t)
                    || contiene(i.getTelefono(), t) || contiene(i.getEmail(), t)).toList();
        }
        if (lista.isEmpty()) return List.of();
        LocalDate hoy = LocalDate.now();
        Map<Integer, Contrato> activos = contratos.activosDeInquilinos(lista.stream().map(Inquilino::getId).toList(), hoy)
                .stream()
                .filter(c -> acceso.puedeVerPiso(c.getHabitacion().getPiso(), actor))
                .collect(Collectors.toMap(c -> c.getInquilino().getId(), Function.identity(), (a, b) -> a));
        return lista.stream().map(i -> respuesta(i, activos.get(i.getId()), List.of(), List.of(), hoy)).toList();
    }

    /** Ficha: datos, contratos (solo los de sus pisos para un propietario) y últimos pagos. */
    @Transactional(readOnly = true)
    public InquilinoResponse obtener(Integer id, UsuarioAutenticado actor) {
        Inquilino i = cargarVisible(id, actor);
        LocalDate hoy = LocalDate.now();
        List<Contrato> suyos = contratos.deInquilino(id, acceso.filtroPropietario(actor));
        List<PagoBreve> ultimosPagos = suyos.isEmpty() ? List.of()
                : pagos.deContratos(suyos.stream().map(Contrato::getId).toList()).stream()
                        .limit(MAX_PAGOS_FICHA).map(PagoBreve::de).toList();
        Contrato activo = suyos.stream().filter(c -> c.estaActivoEn(hoy)).findFirst().orElse(null);
        return respuesta(i, activo, suyos.stream().map(c -> ContratoBreve.de(c, hoy)).toList(), ultimosPagos, hoy);
    }

    @Transactional
    public InquilinoResponse crear(InquilinoRequest req, UsuarioAutenticado actor) {
        String dni = req.dni().trim().toUpperCase(Locale.ROOT);
        if (inquilinos.existsByDni(dni)) {
            throw ApiException.conflicto("DNI_DUPLICADO", "Ya existe un inquilino con el DNI " + dni);
        }
        Inquilino i = new Inquilino();
        copiar(req, i, dni);
        i.setPropietario(usuarios.getReferenceById(actor.id()));
        inquilinos.save(i);
        actividad.registrar(actor.id(), "CREAR_INQUILINO", i.getNombreCompleto());
        return respuesta(i, null, List.of(), List.of(), LocalDate.now());
    }

    @Transactional
    public InquilinoResponse actualizar(Integer id, InquilinoRequest req, UsuarioAutenticado actor) {
        Inquilino i = cargarVisible(id, actor);
        String dni = req.dni().trim().toUpperCase(Locale.ROOT);
        if (inquilinos.existsByDniAndIdNot(dni, id)) {
            throw ApiException.conflicto("DNI_DUPLICADO", "Ya existe otro inquilino con el DNI " + dni);
        }
        copiar(req, i, dni);
        actividad.registrar(actor.id(), "EDITAR_INQUILINO", i.getNombreCompleto());
        return obtener(id, actor);
    }

    @Transactional
    public void borrar(Integer id, UsuarioAutenticado actor) {
        Inquilino i = cargarVisible(id, actor);
        if (contratos.existsByInquilinoId(id) || incidencias.existsByInquilinoId(id)) {
            throw ApiException.conflicto("INQUILINO_CON_HISTORIAL",
                    "No se puede borrar un inquilino con contratos o incidencias registrados");
        }
        inquilinos.delete(i);
        actividad.registrar(actor.id(), "BORRAR_INQUILINO", i.getNombreCompleto());
    }

    /**
     * QR de pago SEPA del alquiler del mes con su contrato activo. A diferencia del
     * escritorio (IBAN de relleno), usa el nombre y el IBAN del propietario del piso.
     */
    @Transactional(readOnly = true)
    public QrPagoResponse qrPago(Integer id, UsuarioAutenticado actor) {
        Inquilino i = cargarVisible(id, actor);
        LocalDate hoy = LocalDate.now();
        Contrato c = contratos.deInquilino(id, acceso.filtroPropietario(actor)).stream()
                .filter(x -> x.estaActivoEn(hoy)).findFirst()
                .orElseThrow(() -> ApiException.conflicto("SIN_CONTRATO_ACTIVO", "El inquilino no tiene contrato activo"));
        Usuario propietario = c.getHabitacion().getPiso().getPropietario();
        if (propietario.getIban() == null || propietario.getIban().isBlank()) {
            boolean esSuyo = propietario.getId().equals(actor.id());
            throw ApiException.conflicto("IBAN_NO_CONFIGURADO", esSuyo
                    ? "Añade tu IBAN en Perfil → Datos de cobro para generar el QR"
                    : "El propietario del piso no tiene IBAN configurado");
        }
        String concepto = recortar("Alquiler Hab." + c.getHabitacion().getNumero() + " " + i.getNombreCompleto()
                + " " + Textos.mes(YearMonth.from(hoy)), 140);
        String beneficiario = recortar(propietario.getNombre(), 70);
        String importe = c.getPrecioMensual().setScale(2, RoundingMode.HALF_UP).toPlainString();
        // EPC069-12 versión 002: el BIC es opcional dentro del EEE.
        String payload = String.join("\n", "BCD", "002", "1", "SCT", "", beneficiario, propietario.getIban(),
                "EUR" + importe, "", "", concepto);
        return new QrPagoResponse(payload, beneficiario, Textos.ibanLegible(propietario.getIban()),
                c.getPrecioMensual(), concepto);
    }

    Inquilino cargarVisible(Integer id, UsuarioAutenticado actor) {
        Inquilino i = inquilinos.findById(id).orElseThrow(() -> ApiException.noEncontrado("Inquilino"));
        if (!actor.esAdmin() && !inquilinos.esVisiblePara(id, actor.id())) throw ApiException.noEncontrado("Inquilino");
        return i;
    }

    private static void copiar(InquilinoRequest req, Inquilino i, String dni) {
        i.setNombre(req.nombre().trim());
        i.setApellidos(req.apellidos().trim());
        i.setDni(dni);
        i.setTelefono(vacioANull(req.telefono()));
        i.setEmail(vacioANull(req.email()));
    }

    private static InquilinoResponse respuesta(Inquilino i, Contrato activo, List<ContratoBreve> contratos,
                                               List<PagoBreve> pagos, LocalDate hoy) {
        return new InquilinoResponse(i.getId(), i.getNombre(), i.getApellidos(), i.getDni(), i.getTelefono(),
                i.getEmail(), i.getUsuario() != null, activo == null ? null : ContratoBreve.de(activo, hoy),
                contratos, pagos);
    }

    private static boolean contiene(String campo, String texto) {
        return campo != null && campo.toLowerCase(Textos.ES).contains(texto);
    }

    private static String vacioANull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static String recortar(String s, int max) {
        return s.length() > max ? s.substring(0, max) : s;
    }
}
