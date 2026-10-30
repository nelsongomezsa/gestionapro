package com.gestionap.api.service;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.Pago;
import com.gestionap.api.domain.Recibo;
import com.gestionap.api.domain.Usuario;
import com.gestionap.api.repository.PagoRepository;
import com.gestionap.api.repository.ReciboRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.ApiException;
import com.itextpdf.io.font.constants.StandardFonts;
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
import com.itextpdf.layout.element.Paragraph;
import com.itextpdf.layout.element.Table;
import com.itextpdf.layout.properties.TextAlignment;
import com.itextpdf.layout.properties.UnitValue;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.text.NumberFormat;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.Collection;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Recibos de pago numerados por propietario y año (2026-0001...). El número se asigna al
 * registrar el pago desde la API o, para los pagos del escritorio, la primera vez que se pide.
 */
@Service
public class ReciboService {

    public record Pdf(String nombreArchivo, byte[] contenido) {}

    private static final DeviceRgb MARINO = new DeviceRgb(15, 27, 51);
    private static final DeviceRgb AZUL = new DeviceRgb(31, 95, 224);
    private static final DeviceRgb GRIS = new DeviceRgb(91, 100, 117);
    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("d 'de' MMMM 'de' yyyy", Textos.ES);

    private final ReciboRepository recibos;
    private final PagoRepository pagos;
    private final ControlAcceso acceso;
    private final EmailService email;
    private final ActividadService actividad;

    public ReciboService(ReciboRepository recibos, PagoRepository pagos, ControlAcceso acceso,
                         EmailService email, ActividadService actividad) {
        this.recibos = recibos;
        this.pagos = pagos;
        this.acceso = acceso;
        this.email = email;
        this.actividad = actividad;
    }

    /**
     * Número del recibo del pago; lo crea si no tiene. La serie del propietario queda
     * bloqueada hasta el commit, así que dos pagos a la vez no comparten número (y la base
     * lo impide además con una clave única).
     */
    @Transactional
    public Recibo asegurar(Pago p) {
        return recibos.findByPagoId(p.getId()).orElseGet(() -> {
            Integer prop = p.getContrato().getHabitacion().getPiso().getPropietario().getId();
            recibos.bloquearSerie(prop);
            int anio = p.getFechaPago().getYear();
            Recibo r = new Recibo();
            r.setPago(p);
            r.setIdPropietario(prop);
            r.setAnio(anio);
            Integer ultimo = recibos.ultimoNumero(prop, anio);
            r.setNumero(ultimo == null ? 1 : ultimo + 1);
            r.setFechaEmision(LocalDateTime.now());
            return recibos.saveAndFlush(r);
        });
    }

    /** Códigos de recibo ya emitidos de esos pagos (los que no tienen, no aparecen). */
    @Transactional(readOnly = true)
    public Map<Integer, String> codigos(Collection<Integer> idsPago) {
        if (idsPago.isEmpty()) return Map.of();
        return recibos.findByPagoIdIn(idsPago).stream()
                .collect(Collectors.toMap(r -> r.getPago().getId(), Recibo::codigo));
    }

    /** PDF del recibo: para el ADMIN, el propietario del piso o el inquilino del contrato. */
    @Transactional
    public Pdf pdf(Integer idPago, UsuarioAutenticado actor) {
        Pago p = cargarVisible(idPago, actor);
        Recibo r = asegurar(p);
        return new Pdf("Recibo-" + r.codigo() + ".pdf", generar(p, r));
    }

    /**
     * Envía el recibo por email al inquilino (el controlador lo limita a ADMIN y PROPIETARIO). Devuelve false si el email del servidor no está
     * configurado o el inquilino no tiene email (la app lo explica y ofrece compartirlo).
     */
    @Transactional
    public boolean enviar(Integer idPago, UsuarioAutenticado actor) {
        Pago p = cargarVisible(idPago, actor);
        var inquilino = p.getContrato().getInquilino();
        if (inquilino.getEmail() == null || inquilino.getEmail().isBlank()) {
            throw ApiException.conflicto("INQUILINO_SIN_EMAIL", "El inquilino no tiene email");
        }
        Recibo r = asegurar(p);
        NumberFormat euros = NumberFormat.getCurrencyInstance(Textos.ES);
        boolean enviado = email.enviar(inquilino.getEmail(), "Recibo " + r.codigo(),
                "Hola, " + inquilino.getNombre() + ":\n\nTe confirmamos el pago de " + euros.format(p.getCantidad())
                        + " del " + p.getFechaPago().format(FECHA) + " (recibo " + r.codigo()
                        + "). Puedes descargar el recibo en PDF desde la app, en «Mi alquiler».\n\nGestionAp");
        if (enviado) actividad.registrar(actor.id(), "ENVIAR_RECIBO", "Recibo " + r.codigo() + " · " + inquilino.getNombreCompleto());
        return enviado;
    }

    private Pago cargarVisible(Integer idPago, UsuarioAutenticado actor) {
        Pago p = pagos.findConDetallesById(idPago).orElseThrow(() -> ApiException.noEncontrado("Pago"));
        if (!acceso.puedeVerContrato(p.getContrato(), actor)) throw ApiException.noEncontrado("Pago");
        return p;
    }

    private byte[] generar(Pago p, Recibo r) {
        Contrato c = p.getContrato();
        var piso = c.getHabitacion().getPiso();
        Usuario propietario = piso.getPropietario();
        var inquilino = c.getInquilino();
        NumberFormat euros = NumberFormat.getCurrencyInstance(Textos.ES);
        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        try (PdfDocument pdf = new PdfDocument(new PdfWriter(salida)); Document doc = new Document(pdf, PageSize.A5.rotate())) {
            PdfFont normal = PdfFontFactory.createFont(StandardFonts.HELVETICA);
            PdfFont negrita = PdfFontFactory.createFont(StandardFonts.HELVETICA_BOLD);
            doc.setMargins(36, 40, 36, 40);

            Table cab = new Table(UnitValue.createPercentArray(new float[]{3, 2})).useAllAvailableWidth();
            cab.addCell(sin(new Paragraph("GestionAp").setFont(negrita).setFontSize(11).setFontColor(AZUL))
                    .add(new Paragraph("RECIBO DE ALQUILER").setFont(negrita).setFontSize(18).setFontColor(MARINO)));
            cab.addCell(sin(new Paragraph("Nº " + r.codigo()).setFont(negrita).setFontSize(14).setFontColor(MARINO)
                            .setTextAlignment(TextAlignment.RIGHT))
                    .add(new Paragraph("Emitido el " + r.getFechaEmision().toLocalDate().format(FECHA))
                            .setFont(normal).setFontSize(8).setFontColor(GRIS).setTextAlignment(TextAlignment.RIGHT)));
            doc.add(cab.setMarginBottom(14));

            Table partes = new Table(UnitValue.createPercentArray(new float[]{1, 1})).useAllAvailableWidth();
            partes.addCell(parte("ARRENDADOR", propietario.getNombre(), propietario.getDni(), normal, negrita));
            partes.addCell(parte("ARRENDATARIO", inquilino.getNombreCompleto(), inquilino.getDni(), normal, negrita));
            doc.add(partes.setMarginBottom(12));

            String concepto = "Renta de " + Textos.mes(YearMonth.from(p.getFechaPago())) + " · habitación "
                    + c.getHabitacion().getNumero() + ", " + piso.getDireccion() + ", " + piso.getCiudad().getNombre();
            Table detalle = new Table(UnitValue.createPercentArray(new float[]{3, 1})).useAllAvailableWidth();
            detalle.addCell(sin(etiqueta("CONCEPTO", negrita)).add(new Paragraph(concepto).setFont(normal).setFontSize(10)));
            detalle.addCell(sin(etiqueta("IMPORTE", negrita).setTextAlignment(TextAlignment.RIGHT))
                    .add(new Paragraph(euros.format(p.getCantidad())).setFont(negrita).setFontSize(16)
                            .setFontColor(MARINO).setTextAlignment(TextAlignment.RIGHT)));
            doc.add(detalle.setBorderTop(new SolidBorder(GRIS, 0.5f)).setBorderBottom(new SolidBorder(GRIS, 0.5f))
                    .setPaddingTop(6).setPaddingBottom(6).setMarginBottom(10));

            doc.add(new Paragraph("Pagado el " + p.getFechaPago().format(FECHA) + " por " + metodo(p) + ".")
                    .setFont(normal).setFontSize(9));
            doc.add(new Paragraph("El arrendador declara haber recibido del arrendatario la cantidad indicada "
                    + "en concepto de renta del contrato nº " + c.getId() + ".")
                    .setFont(normal).setFontSize(9).setFontColor(GRIS));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        return salida.toByteArray();
    }

    private static String metodo(Pago p) {
        return switch (p.getMetodoPago()) {
            case transferencia -> "transferencia";
            case efectivo -> "efectivo";
            case domiciliacion -> "domiciliación bancaria";
        };
    }

    private static Cell parte(String titulo, String nombre, String dni, PdfFont normal, PdfFont negrita) {
        Cell c = sin(etiqueta(titulo, negrita)).add(new Paragraph(nombre).setFont(negrita).setFontSize(10));
        if (dni != null && !dni.isBlank()) c.add(new Paragraph("DNI/NIE " + dni).setFont(normal).setFontSize(9).setFontColor(GRIS));
        return c;
    }

    private static Paragraph etiqueta(String texto, PdfFont negrita) {
        return new Paragraph(texto).setFont(negrita).setFontSize(7).setFontColor(GRIS).setMarginBottom(2);
    }

    private static Cell sin(Paragraph p) {
        return new Cell().add(p).setBorder(Border.NO_BORDER).setPadding(0);
    }
}
