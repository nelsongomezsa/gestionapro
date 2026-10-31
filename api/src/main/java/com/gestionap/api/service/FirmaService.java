package com.gestionap.api.service;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.FirmaContrato;
import com.gestionap.api.domain.FirmaContrato.Parte;
import com.gestionap.api.domain.Rol;
import com.gestionap.api.repository.FirmaContratoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.itextpdf.io.font.constants.StandardFonts;
import com.itextpdf.io.image.ImageDataFactory;
import com.itextpdf.kernel.colors.DeviceRgb;
import com.itextpdf.kernel.font.PdfFont;
import com.itextpdf.kernel.font.PdfFontFactory;
import com.itextpdf.kernel.pdf.PdfDocument;
import com.itextpdf.kernel.pdf.PdfReader;
import com.itextpdf.kernel.pdf.PdfWriter;
import com.itextpdf.layout.Document;
import com.itextpdf.layout.borders.Border;
import com.itextpdf.layout.element.AreaBreak;
import com.itextpdf.layout.element.Cell;
import com.itextpdf.layout.element.Image;
import com.itextpdf.layout.element.Paragraph;
import com.itextpdf.layout.element.Table;
import com.itextpdf.layout.properties.AreaBreakType;
import com.itextpdf.layout.properties.UnitValue;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;
import java.util.List;

/**
 * Firma de contratos en pantalla: firma electrónica SIMPLE (Reglamento (UE) 910/2014, eIDAS).
 * Cada parte dibuja su firma; se guarda la imagen, quién, cuándo, desde qué IP y la huella
 * SHA-256 de los datos del contrato firmado, y el PDF firmado añade una hoja de firmas con esos datos.
 * Para una firma avanzada o cualificada habría que delegar en un proveedor de confianza
 * (ver docs/FIRMA.md): el campo "proveedor" y este servicio son el punto donde se enchufaría.
 */
@Service
public class FirmaService {

    public record Firma(Parte parte, String nombre, String dni, String fecha, String proveedor, boolean vigente) {}

    public record Estado(List<Firma> firmas, boolean completo, boolean cambiadoTrasFirmar, String huellaActual) {}

    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("d/MM/yyyy HH:mm", Textos.ES);

    private final FirmaContratoRepository firmas;
    private final ContratoService contratos;
    private final ArchivoService archivos;
    private final ActividadService actividad;

    public FirmaService(FirmaContratoRepository firmas, ContratoService contratos, ArchivoService archivos,
                        ActividadService actividad) {
        this.firmas = firmas;
        this.contratos = contratos;
        this.archivos = archivos;
        this.actividad = actividad;
    }

    @Transactional(readOnly = true)
    public Estado estado(Integer idContrato, UsuarioAutenticado actor) {
        String huella = huella(contratos.cargarVisible(idContrato, actor));
        List<FirmaContrato> lista = firmas.findByContratoIdOrderByFechaAsc(idContrato);
        List<Firma> salida = lista.stream()
                .map(f -> new Firma(f.getParte(), f.getNombre(), f.getDni(), f.getFecha().format(FECHA), f.getProveedor(),
                        f.getHuellaPdf().equals(huella)))
                .toList();
        boolean completo = salida.size() == Parte.values().length && salida.stream().allMatch(Firma::vigente);
        boolean cambiado = salida.stream().anyMatch(f -> !f.vigente());
        return new Estado(salida, completo, cambiado, huella);
    }

    /**
     * El propietario (o el admin) puede recoger las dos firmas en su dispositivo si firman en
     * persona; el inquilino solo la suya. Una firma ya hecha no se sobrescribe (salvo que el
     * contrato haya cambiado desde entonces).
     */
    @Transactional
    public Estado firmar(Integer idContrato, Parte parte, MultipartFile imagen, String ip, UsuarioAutenticado actor) {
        Contrato c = contratos.cargarVisible(idContrato, actor);
        if (actor.rol() == Rol.INQUILINO && parte != Parte.ARRENDATARIO) {
            throw new org.springframework.security.access.AccessDeniedException("El inquilino solo firma como arrendatario");
        }
        String huella = huella(c);
        var anterior = firmas.findByContratoIdOrderByFechaAsc(idContrato).stream().filter(f -> f.getParte() == parte).findFirst();
        if (anterior.isPresent() && anterior.get().getHuellaPdf().equals(huella)) {
            throw ApiException.conflicto("YA_FIRMADO", "Esta parte ya ha firmado el contrato");
        }
        // Primero se guarda y valida la imagen nueva; la anterior solo se borra cuando la nueva ya está en la base.
        var guardada = archivos.guardar("firmas", imagen);
        if (!guardada.tipo().equals("image/png")) {
            archivos.borrar(guardada.ruta());
            throw ApiException.badRequest("TIPO_NO_ADMITIDO", "La firma se envía como imagen PNG");
        }
        String imagenAnterior = null;
        if (anterior.isPresent()) {
            // El contrato cambió (p. ej., la renta): la firma anterior ya no vale y se sustituye.
            imagenAnterior = anterior.get().getImagenRuta();
            firmas.delete(anterior.get());
            firmas.flush();
        }
        FirmaContrato f = new FirmaContrato();
        f.setContrato(c);
        f.setParte(parte);
        if (parte == Parte.ARRENDADOR) {
            f.setNombre(c.getHabitacion().getPiso().getPropietario().getNombre());
            f.setDni(c.getHabitacion().getPiso().getPropietario().getDni());
        } else {
            f.setNombre(c.getInquilino().getNombreCompleto());
            f.setDni(c.getInquilino().getDni());
        }
        f.setIdUsuario(actor.id());
        f.setImagenRuta(guardada.ruta());
        f.setFecha(LocalDateTime.now());
        f.setIp(ip);
        f.setHuellaPdf(huella);
        try {
            firmas.saveAndFlush(f);
        } catch (DataIntegrityViolationException e) {
            archivos.borrar(guardada.ruta());
            throw ApiException.conflicto("YA_FIRMADO", "Esta parte ya ha firmado el contrato");
        }
        if (imagenAnterior != null) archivos.borrar(imagenAnterior);
        actividad.registrar(actor.id(), "FIRMAR_CONTRATO", "Contrato #" + idContrato + " · " + parte.name().toLowerCase());
        return estado(idContrato, actor);
    }

    /** El contrato en PDF con una hoja final de firmas (imagen, nombre, DNI, fecha, IP y huella). */
    @Transactional(readOnly = true)
    public ContratoService.Pdf pdfFirmado(Integer idContrato, UsuarioAutenticado actor) {
        ContratoService.Pdf base = contratos.pdf(idContrato, actor);
        String huella = huella(contratos.cargarVisible(idContrato, actor));
        List<FirmaContrato> lista = firmas.findByContratoIdOrderByFechaAsc(idContrato);
        if (lista.isEmpty()) throw ApiException.conflicto("SIN_FIRMAS", "El contrato aún no tiene firmas");
        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        try (PdfDocument pdf = new PdfDocument(new PdfReader(new ByteArrayInputStream(base.contenido())), new PdfWriter(salida));
             Document doc = new Document(pdf)) {
            PdfFont normal = PdfFontFactory.createFont(StandardFonts.HELVETICA);
            PdfFont negrita = PdfFontFactory.createFont(StandardFonts.HELVETICA_BOLD);
            DeviceRgb gris = new DeviceRgb(91, 100, 117);
            doc.add(new AreaBreak(AreaBreakType.LAST_PAGE));
            doc.add(new AreaBreak(AreaBreakType.NEXT_PAGE));
            doc.add(new Paragraph("HOJA DE FIRMAS").setFont(negrita).setFontSize(16).setMarginBottom(12));
            Table t = new Table(UnitValue.createPercentArray(new float[]{1, 1})).useAllAvailableWidth();
            for (FirmaContrato f : lista) {
                Cell celda = new Cell().setBorder(Border.NO_BORDER).setPadding(6);
                celda.add(new Paragraph(f.getParte() == FirmaContrato.Parte.ARRENDADOR ? "EL ARRENDADOR" : "EL ARRENDATARIO")
                        .setFont(negrita).setFontSize(9).setFontColor(gris));
                byte[] imagen = archivos.leer(f.getImagenRuta(), "image/png").datos();
                celda.add(new Image(ImageDataFactory.create(imagen)).setAutoScale(true).setMaxHeight(80));
                celda.add(new Paragraph(f.getNombre() + (f.getDni() != null ? " · " + f.getDni() : "")).setFont(normal).setFontSize(9));
                celda.add(new Paragraph("Firmado el " + f.getFecha().format(FECHA) + (f.getIp() != null ? " desde " + f.getIp() : ""))
                        .setFont(normal).setFontSize(8).setFontColor(gris));
                if (!f.getHuellaPdf().equals(huella)) {
                    celda.add(new Paragraph("Atención: el contrato ha cambiado después de esta firma.").setFont(negrita)
                            .setFontSize(8).setFontColor(new DeviceRgb(198, 40, 40)));
                }
                t.addCell(celda);
            }
            if (lista.size() % 2 == 1) t.addCell(new Cell().setBorder(Border.NO_BORDER));
            doc.add(t.setMarginBottom(16));
            doc.add(new Paragraph("Firma electrónica simple en pantalla (Reglamento (UE) 910/2014). Huella SHA-256 de los datos del "
                    + "contrato firmado: " + huella + ". Si el contrato cambia, la huella deja de coincidir.")
                    .setFont(normal).setFontSize(8).setFontColor(gris));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        return new ContratoService.Pdf(base.nombreArchivo().replace(".pdf", "-firmado.pdf"), salida.toByteArray());
    }

    /**
     * Huella SHA-256 de lo que se firma: partes, DNI, habitación, piso, fechas y renta. No se usa
     * el PDF porque cada descarga lleva la fecha del día y metadatos distintos.
     */
    static String huella(Contrato c) {
        var piso = c.getHabitacion().getPiso();
        String contenido = String.join("|", String.valueOf(c.getId()),
                piso.getPropietario().getNombre(), String.valueOf(piso.getPropietario().getDni()),
                c.getInquilino().getNombreCompleto(), String.valueOf(c.getInquilino().getDni()),
                piso.getDireccion(), piso.getCiudad().getNombre(), String.valueOf(c.getHabitacion().getNumero()),
                c.getFechaInicio().toString(), c.getFechaFin().toString(), c.getPrecioMensual().toPlainString());
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(contenido.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
