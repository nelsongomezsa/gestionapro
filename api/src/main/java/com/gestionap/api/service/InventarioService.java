package com.gestionap.api.service;

import com.gestionap.api.domain.*;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.HabitacionRepository;
import com.gestionap.api.repository.InventarioRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.gestionap.api.web.dto.InventarioDtos.InventarioRequest;
import com.gestionap.api.web.dto.InventarioDtos.InventarioResponse;
import com.itextpdf.io.font.constants.StandardFonts;
import com.itextpdf.io.image.ImageDataFactory;
import com.itextpdf.kernel.colors.DeviceRgb;
import com.itextpdf.kernel.font.PdfFont;
import com.itextpdf.kernel.font.PdfFontFactory;
import com.itextpdf.kernel.geom.PageSize;
import com.itextpdf.kernel.pdf.PdfDocument;
import com.itextpdf.kernel.pdf.PdfWriter;
import com.itextpdf.layout.Document;
import com.itextpdf.layout.borders.Border;
import com.itextpdf.layout.borders.SolidBorder;
import com.itextpdf.layout.element.Cell;
import com.itextpdf.layout.element.Image;
import com.itextpdf.layout.element.Paragraph;
import com.itextpdf.layout.element.Table;
import com.itextpdf.layout.properties.UnitValue;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * Inventario de entrada y de salida por habitación, con fotos opcionales y PDF para firmar.
 * Lo gestiona el propietario del piso (o el admin); el inquilino ve los de sus contratos.
 */
@Service
public class InventarioService {

    public record Pdf(String nombreArchivo, byte[] contenido) {}

    private static final DeviceRgb MARINO = new DeviceRgb(15, 27, 51);
    private static final DeviceRgb AZUL = new DeviceRgb(31, 95, 224);
    private static final DeviceRgb GRIS = new DeviceRgb(91, 100, 117);
    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("d 'de' MMMM 'de' yyyy", Textos.ES);

    private final InventarioRepository inventarios;
    private final HabitacionRepository habitaciones;
    private final ContratoRepository contratos;
    private final ControlAcceso acceso;
    private final ArchivoService archivos;
    private final ActividadService actividad;

    public InventarioService(InventarioRepository inventarios, HabitacionRepository habitaciones, ContratoRepository contratos,
                             ControlAcceso acceso, ArchivoService archivos, ActividadService actividad) {
        this.inventarios = inventarios;
        this.habitaciones = habitaciones;
        this.contratos = contratos;
        this.acceso = acceso;
        this.archivos = archivos;
        this.actividad = actividad;
    }

    @Transactional(readOnly = true)
    public List<InventarioResponse> listar(Integer idHabitacion, UsuarioAutenticado actor) {
        Habitacion h = habitaciones.findConPisoById(idHabitacion).orElseThrow(() -> ApiException.noEncontrado("Habitación"));
        return inventarios.findByHabitacionIdOrderByFechaDescIdDesc(idHabitacion).stream()
                .filter(i -> puedeVer(i, h, actor))
                .map(InventarioResponse::de).toList();
    }

    @Transactional(readOnly = true)
    public InventarioResponse obtener(Integer id, UsuarioAutenticado actor) {
        return InventarioResponse.de(cargarVisible(id, actor));
    }

    @Transactional
    public InventarioResponse crear(Integer idHabitacion, InventarioRequest req, UsuarioAutenticado actor) {
        Habitacion h = habitaciones.findConPisoById(idHabitacion).orElseThrow(() -> ApiException.noEncontrado("Habitación"));
        if (!acceso.puedeVerPiso(h.getPiso(), actor)) throw ApiException.noEncontrado("Habitación");
        Inventario i = new Inventario();
        i.setHabitacion(h);
        if (req.idContrato() != null) {
            Contrato c = contratos.findConDetallesById(req.idContrato())
                    .filter(x -> x.getHabitacion().getId().equals(idHabitacion))
                    .orElseThrow(() -> ApiException.badRequest("CONTRATO_NO_VALIDO", "El contrato no es de esta habitación"));
            i.setContrato(c);
        }
        i.setTipo(req.tipo());
        i.setFecha(req.fecha());
        i.setObservaciones(req.observaciones() == null || req.observaciones().isBlank() ? null : req.observaciones().trim());
        i.setFechaAlta(LocalDateTime.now());
        int orden = 0;
        for (var e : req.elementos()) {
            ElementoInventario el = new ElementoInventario();
            el.setInventario(i);
            el.setNombre(e.nombre().trim());
            el.setEstado(e.estado());
            el.setObservaciones(e.observaciones() == null || e.observaciones().isBlank() ? null : e.observaciones().trim());
            el.setOrden(orden++);
            i.getElementos().add(el);
        }
        inventarios.save(i);
        actividad.registrar(actor.id(), "CREAR_INVENTARIO",
                "Hab. " + h.getNumero() + " · " + h.getPiso().getDireccion() + " · " + req.tipo().name().toLowerCase());
        return InventarioResponse.de(i);
    }

    @Transactional
    public void borrar(Integer id, UsuarioAutenticado actor) {
        Inventario i = cargarGestionable(id, actor);
        i.getElementos().forEach(e -> archivos.borrar(e.getFotoRuta()));
        inventarios.delete(i);
    }

    @Transactional
    public InventarioResponse subirFoto(Integer idElemento, MultipartFile archivo, UsuarioAutenticado actor) {
        ElementoInventario e = inventarios.elemento(idElemento).orElseThrow(() -> ApiException.noEncontrado("Elemento"));
        cargarGestionable(e.getInventario().getId(), actor);
        var guardado = archivos.guardar("inventarios", archivo);
        if (guardado.tipo().equals("application/pdf")) {
            archivos.borrar(guardado.ruta());
            throw ApiException.badRequest("TIPO_NO_ADMITIDO", "Solo fotos (JPEG, PNG o HEIC)");
        }
        archivos.borrar(e.getFotoRuta());
        e.setFotoRuta(guardado.ruta());
        e.setFotoTipo(guardado.tipo());
        return InventarioResponse.de(e.getInventario());
    }

    @Transactional(readOnly = true)
    public ArchivoService.Contenido foto(Integer idElemento, UsuarioAutenticado actor) {
        ElementoInventario e = inventarios.elemento(idElemento).orElseThrow(() -> ApiException.noEncontrado("Elemento"));
        cargarVisible(e.getInventario().getId(), actor);
        if (e.getFotoRuta() == null) throw ApiException.noEncontrado("Foto");
        return archivos.leer(e.getFotoRuta(), e.getFotoTipo());
    }

    /** PDF con los elementos, su estado y sus fotos (las HEIC no se pueden incrustar: se indica). */
    @Transactional(readOnly = true)
    public Pdf pdf(Integer id, UsuarioAutenticado actor) {
        Inventario i = cargarVisible(id, actor);
        Habitacion h = i.getHabitacion();
        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        try (PdfDocument pdf = new PdfDocument(new PdfWriter(salida)); Document doc = new Document(pdf, PageSize.A4)) {
            PdfFont normal = PdfFontFactory.createFont(StandardFonts.HELVETICA);
            PdfFont negrita = PdfFontFactory.createFont(StandardFonts.HELVETICA_BOLD);
            doc.setMargins(48, 48, 48, 48);
            doc.add(new Paragraph("GestionAp").setFont(negrita).setFontSize(11).setFontColor(AZUL));
            doc.add(new Paragraph("INVENTARIO DE " + i.getTipo().name()).setFont(negrita).setFontSize(18).setFontColor(MARINO));
            doc.add(new Paragraph("Habitación " + h.getNumero() + " · " + h.getPiso().getDireccion() + ", "
                    + h.getPiso().getCiudad().getNombre()).setFont(normal).setFontSize(10));
            String inquilino = i.getContrato() != null ? " · Inquilino: " + i.getContrato().getInquilino().getNombreCompleto() : "";
            doc.add(new Paragraph("Fecha: " + i.getFecha().format(FECHA) + inquilino)
                    .setFont(normal).setFontSize(9).setFontColor(GRIS).setMarginBottom(14));

            Table t = new Table(UnitValue.createPercentArray(new float[]{3, 1.4f, 3.6f, 2.2f})).useAllAvailableWidth();
            for (String c : new String[]{"ELEMENTO", "ESTADO", "OBSERVACIONES", "FOTO"}) {
                t.addHeaderCell(new Cell().add(new Paragraph(c).setFont(negrita).setFontSize(7).setFontColor(GRIS))
                        .setBorder(Border.NO_BORDER).setBorderBottom(new SolidBorder(GRIS, 0.5f)));
            }
            for (ElementoInventario e : i.getElementos()) {
                t.addCell(celda(e.getNombre(), negrita));
                t.addCell(celda(estado(e.getEstado()), normal));
                t.addCell(celda(e.getObservaciones() == null ? "—" : e.getObservaciones(), normal));
                t.addCell(foto(e, normal));
            }
            doc.add(t.setMarginBottom(14));
            if (i.getObservaciones() != null) {
                doc.add(new Paragraph("Observaciones: " + i.getObservaciones()).setFont(normal).setFontSize(9).setMarginBottom(24));
            }
            Table firmas = new Table(UnitValue.createPercentArray(new float[]{1, 1})).useAllAvailableWidth().setMarginTop(30);
            firmas.addCell(celda("Firma del arrendador", normal).setBorderTop(new SolidBorder(GRIS, 0.5f)));
            firmas.addCell(celda("Firma del arrendatario", normal).setBorderTop(new SolidBorder(GRIS, 0.5f)));
            doc.add(firmas);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        String nombre = "Inventario-" + i.getTipo().name().toLowerCase() + "-hab" + h.getNumero() + "-" + i.getFecha() + ".pdf";
        return new Pdf(nombre, salida.toByteArray());
    }

    private Cell foto(ElementoInventario e, PdfFont normal) {
        if (e.getFotoRuta() == null) return celda("—", normal);
        if (e.getFotoTipo().equals("image/heic")) return celda("Foto en la app (HEIC)", normal);
        byte[] datos = archivos.leer(e.getFotoRuta(), e.getFotoTipo()).datos();
        return new Cell().add(new Image(ImageDataFactory.create(datos)).setAutoScale(true).setMaxHeight(90))
                .setBorder(Border.NO_BORDER).setPadding(4);
    }

    private static String estado(ElementoInventario.Estado e) {
        return switch (e) {
            case NUEVO -> "Nuevo";
            case BUENO -> "Buen estado";
            case USADO -> "Uso normal";
            case DANADO -> "Dañado";
        };
    }

    private static Cell celda(String texto, PdfFont fuente) {
        return new Cell().add(new Paragraph(texto).setFont(fuente).setFontSize(9)).setBorder(Border.NO_BORDER).setPadding(4);
    }

    private Inventario cargarVisible(Integer id, UsuarioAutenticado actor) {
        Inventario i = inventarios.findById(id).orElseThrow(() -> ApiException.noEncontrado("Inventario"));
        if (!puedeVer(i, i.getHabitacion(), actor)) throw ApiException.noEncontrado("Inventario");
        return i;
    }

    private Inventario cargarGestionable(Integer id, UsuarioAutenticado actor) {
        Inventario i = cargarVisible(id, actor);
        if (actor.rol() == Rol.INQUILINO) throw new org.springframework.security.access.AccessDeniedException("Solo lectura");
        return i;
    }

    /** El propietario del piso o el admin; el inquilino, solo los de sus contratos. */
    private boolean puedeVer(Inventario i, Habitacion h, UsuarioAutenticado actor) {
        if (actor.rol() == Rol.INQUILINO) return i.getContrato() != null && acceso.puedeVerContrato(i.getContrato(), actor);
        return acceso.puedeVerPiso(h.getPiso(), actor);
    }
}
