package com.gestionap.api.service;

import com.gestionap.api.domain.TipoUnidad;
import com.gestionap.api.domain.Vehiculo;
import io.swagger.v3.oas.annotations.media.Schema;
import com.itextpdf.io.font.constants.StandardFonts;
import com.itextpdf.kernel.colors.DeviceRgb;
import com.itextpdf.kernel.events.Event;
import com.itextpdf.kernel.events.IEventHandler;
import com.itextpdf.kernel.events.PdfDocumentEvent;
import com.itextpdf.kernel.font.PdfFont;
import com.itextpdf.kernel.font.PdfFontFactory;
import com.itextpdf.kernel.geom.PageSize;
import com.itextpdf.kernel.geom.Rectangle;
import com.itextpdf.kernel.pdf.PdfDocument;
import com.itextpdf.kernel.pdf.PdfPage;
import com.itextpdf.kernel.pdf.PdfWriter;
import com.itextpdf.kernel.pdf.canvas.PdfCanvas;
import com.itextpdf.layout.Document;
import com.itextpdf.layout.borders.Border;
import com.itextpdf.layout.element.*;
import com.itextpdf.layout.properties.TextAlignment;
import org.springframework.stereotype.Component;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.Set;

/**
 * Contrato de arrendamiento de habitación en PDF (iText 7), a partir de
 * plantillas/plantilla_contrato.txt.
 *
 * <p>Portado de ContratoGenerator del escritorio: la plantilla, el maquetado
 * (renderPdf y siguientes) y el pie de página son los mismos. Cambia solo la
 * entrada y la salida: recibe los datos ya cargados (el arrendador sale del
 * usuario propietario, no de un texto fijo) y devuelve los bytes del PDF en
 * vez de guardarlo en el Escritorio.
 */
@Component
public class ContratoPdfGenerator {

    /** Todo lo que necesita la plantilla. Los textos nulos o vacíos se imprimen como "—". */
    public record DatosContrato(
            int idContrato,
            String arrendadorNombre,
            String arrendadorDni,
            String arrendatarioNombre,
            String arrendatarioDni,
            String direccionPiso,
            String ciudad,
            int numeroHabitacion,
            LocalDate fechaInicio,
            LocalDate fechaFin,
            BigDecimal precioMensual,
            TipoUnidad tipoUnidad,
            String planta,
            BigDecimal metros,
            Vehiculo vehiculo,
            boolean aplicaIva,
            BigDecimal ivaPct,
            @Schema(description = "null si el contrato no tiene fianza registrada") BigDecimal fianza) {

        /** Contrato de habitación (el de siempre): fianza de una mensualidad, sin IVA. */
        public DatosContrato(int idContrato, String arrendadorNombre, String arrendadorDni, String arrendatarioNombre,
                             String arrendatarioDni, String direccionPiso, String ciudad, int numeroHabitacion,
                             LocalDate fechaInicio, LocalDate fechaFin, BigDecimal precioMensual) {
            this(idContrato, arrendadorNombre, arrendadorDni, arrendatarioNombre, arrendatarioDni, direccionPiso, ciudad,
                    numeroHabitacion, fechaInicio, fechaFin, precioMensual, TipoUnidad.habitacion, null, null, null,
                    false, null, precioMensual);
        }
    }

    private static String plantilla(TipoUnidad tipo) {
        return switch (tipo) {
            case habitacion -> "/plantillas/plantilla_contrato.txt";
            case plaza -> "/plantillas/plantilla_contrato_plaza.txt";
            case trastero -> "/plantillas/plantilla_contrato_trastero.txt";
        };
    }

    private static String subtitulo(TipoUnidad tipo) {
        return switch (tipo) {
            case habitacion -> "DE HABITACIÓN EN PISO COMPARTIDO";
            case plaza -> "DE PLAZA DE GARAJE";
            case trastero -> "DE TRASTERO";
        };
    }

    private static String pie(TipoUnidad tipo) {
        return switch (tipo) {
            case habitacion -> "Arrendamiento de habitación en piso compartido";
            case plaza -> "Arrendamiento de plaza de garaje";
            case trastero -> "Arrendamiento de trastero";
        };
    }

    /** ", planta -1, 12 m²" (lo que se haya indicado). */
    private static String detalleUnidad(DatosContrato d) {
        StringBuilder sb = new StringBuilder();
        if (d.planta() != null && !d.planta().isBlank()) sb.append(", planta ").append(d.planta());
        if (d.metros() != null) sb.append(", de ").append(d.metros().stripTrailingZeros().toPlainString().replace('.', ',')).append(" m²");
        return sb.toString();
    }

    private static String rentaTexto(DatosContrato d) {
        String total = euros(d.precioMensual());
        if (!d.aplicaIva() || d.ivaPct() == null) return "La renta mensual pactada es de " + total + ".";
        var iva = Iva.desglosar(d.precioMensual(), d.ivaPct());
        return "La renta mensual pactada es de " + total + ", IVA incluido (base imponible " + euros(iva.base())
                + " más IVA del " + iva.pct().stripTrailingZeros().toPlainString().replace('.', ',') + " %, "
                + euros(iva.cuota()) + ").";
    }

    private static String fianzaTexto(DatosContrato d) {
        if (d.fianza() == null || d.fianza().signum() == 0) {
            return "Las partes acuerdan no constituir fianza.";
        }
        return "A la firma del presente contrato, el ARRENDATARIO entrega al ARRENDADOR " + euros(d.fianza())
                + " en concepto de fianza, que se devolverá al terminar el contrato tras comprobar el estado de lo arrendado "
                + "y la devolución de llaves y mandos, descontando en su caso los daños o rentas pendientes.";
    }

    private static String euros(BigDecimal importe) {
        return Textos.euros(importe);
    }

    // ── Colores ──────────────────────────────────────────────────
    private static final DeviceRgb PURPLE     = new DeviceRgb(108,  99, 255);
    private static final DeviceRgb DARK       = new DeviceRgb( 30,  30,  60);
    private static final DeviceRgb DARK_GRAY  = new DeviceRgb( 60,  60,  90);
    private static final DeviceRgb GRAY       = new DeviceRgb(100, 100, 130);
    private static final DeviceRgb LIGHT_BG   = new DeviceRgb(245, 245, 252);

    // ── Formatos de fecha ────────────────────────────────────────
    private static final DateTimeFormatter FMT_ES =
            DateTimeFormatter.ofPattern("dd 'de' MMMM 'de' yyyy", Locale.of("es", "ES"));
    private static final DateTimeFormatter FMT_FILE =
            DateTimeFormatter.ofPattern("yyyyMMdd");

    // ── Títulos de cláusula (ordinales en español) ───────────────
    private static final Set<String> ORDINALS = Set.of(
            "PRIMERA", "SEGUNDA", "TERCERA", "CUARTA", "QUINTA", "SEXTA",
            "SÉPTIMA", "OCTAVA", "NOVENA", "DÉCIMA", "UNDÉCIMA",
            "DUODÉCIMA", "DECIMOTERCERA", "DECIMOCUARTA", "DECIMOQUINTA",
            "DECIMOSEXTA", "DECIMOSÉPTIMA", "DECIMOCTAVA", "DECIMONOVENA",
            "VIGÉSIMA", "VIGÉSIMA PRIMERA", "VIGÉSIMA SEGUNDA",
            "VIGÉSIMA TERCERA", "VIGÉSIMA CUARTA", "VIGÉSIMA QUINTA"
    );

    // ── Marcadores de sección ────────────────────────────────────
    private static final Set<String> SECTION_MARKERS = Set.of(
            "REUNIDOS:", "EXPONEN:", "CLÁUSULAS:", "FIRMA:"
    );

    // ── Punto de entrada ─────────────────────────────────────────

    public byte[] generar(DatosContrato d) {
        String template;
        String rutaPlantilla = plantilla(d.tipoUnidad());
        try (InputStream is = ContratoPdfGenerator.class.getResourceAsStream(rutaPlantilla)) {
            if (is == null)
                throw new IllegalStateException("No se encontró " + rutaPlantilla + " en recursos.");
            template = new String(is.readAllBytes(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }

        String direccion = nvl(d.direccionPiso());
        String ciudad    = nvl(d.ciudad());
        String nombreInq = nvl(d.arrendatarioNombre());
        String dniInq    = nvl(d.arrendatarioDni());

        String texto = template
                .replace("{{ARRENDADOR_NOMBRE}}",   nvl(d.arrendadorNombre()))
                .replace("{{ARRENDADOR_DNI}}",       nvl(d.arrendadorDni()))
                .replace("{{ARRENDATARIO_NOMBRE}}", nombreInq)
                .replace("{{ARRENDATARIO_DNI}}",    dniInq)
                .replace("{{DIRECCION_PISO}}",      direccion)
                .replace("{{CIUDAD}}",              ciudad)
                .replace("{{NUMERO_HABITACION}}",   String.valueOf(d.numeroHabitacion()))
                .replace("{{FECHA_INICIO}}",        d.fechaInicio().format(FMT_ES))
                .replace("{{FECHA_FIN}}",           d.fechaFin().format(FMT_ES))
                .replace("{{RENTA_MENSUAL}}",       d.precioMensual().toPlainString())
                .replace("{{FIANZA}}",              (d.fianza() != null ? d.fianza() : d.precioMensual()).toPlainString())
                .replace("{{RENTA_TEXTO}}",         rentaTexto(d))
                .replace("{{FIANZA_TEXTO}}",        fianzaTexto(d))
                .replace("{{DETALLE_UNIDAD}}",      detalleUnidad(d))
                .replace("{{VEHICULO}}",            d.vehiculo() == Vehiculo.moto ? "una motocicleta" : "un vehículo")
                .replace("{{SUMINISTROS_INCLUIDOS}}", "La renta incluye agua, electricidad e internet.")
                .replace("{{FECHA_HOY}}",           LocalDate.now().format(FMT_ES));

        try {
            PdfFont fontNormal = PdfFontFactory.createFont(StandardFonts.HELVETICA);
            PdfFont fontBold   = PdfFontFactory.createFont(StandardFonts.HELVETICA_BOLD);

            ByteArrayOutputStream salida = new ByteArrayOutputStream();
            PdfDocument pdf = new PdfDocument(new PdfWriter(salida));
            pdf.addEventHandler(PdfDocumentEvent.END_PAGE,
                    new PageFooterHandler(fontNormal, d.idContrato(), pie(d.tipoUnidad())));

            // Márgenes: 2.54 cm ≈ 72 pt
            Document doc = new Document(pdf, PageSize.A4);
            doc.setMargins(72, 72, 72, 72);

            renderPdf(doc, texto, fontNormal, fontBold, direccion, ciudad,
                      nombreInq, dniInq, subtitulo(d.tipoUnidad()));

            doc.close();
            return salida.toByteArray();
        } catch (IOException e) {
            throw new UncheckedIOException("No se pudo generar el PDF del contrato", e);
        }
    }

    /** Mismo nombre de archivo que usaba el escritorio. */
    public String nombreArchivo(DatosContrato d) {
        return "Contrato_" + nvl(d.arrendatarioNombre()).replace(" ", "_") + "_"
                + LocalDate.now().format(FMT_FILE) + ".pdf";
    }

    // ── Renderizado del PDF ──────────────────────────────────────

    private static void renderPdf(Document doc, String texto, PdfFont fontNormal,
                                  PdfFont fontBold, String direccion, String ciudad,
                                  String nombreInq, String dniInq, String subtitulo) {
        // ── Cabecera del documento ──
        doc.add(new Paragraph("CONTRATO DE ARRENDAMIENTO")
                .setFont(fontBold).setFontSize(16).setFontColor(PURPLE)
                .setTextAlignment(TextAlignment.CENTER).setMarginBottom(2));
        doc.add(new Paragraph(subtitulo)
                .setFont(fontBold).setFontSize(16).setFontColor(PURPLE)
                .setTextAlignment(TextAlignment.CENTER).setMarginBottom(6));
        doc.add(new Paragraph(direccion + " — " + ciudad)
                .setFont(fontNormal).setFontSize(10).setFontColor(GRAY)
                .setTextAlignment(TextAlignment.CENTER).setMarginBottom(2));
        doc.add(new Paragraph("Generado el " + LocalDate.now().format(FMT_ES))
                .setFont(fontNormal).setFontSize(9).setFontColor(GRAY)
                .setTextAlignment(TextAlignment.CENTER).setMarginBottom(14));
        doc.add(new Table(1).useAllAvailableWidth()
                .addCell(new Cell().setHeight(1f)
                        .setBackgroundColor(PURPLE).setBorder(Border.NO_BORDER))
                .setMarginBottom(18));

        // ── Procesar líneas de la plantilla ──
        String[] lines = texto.split("\n");
        StringBuilder accumulator = new StringBuilder();
        boolean inSignature = false;
        boolean inAnexo     = false;

        for (String rawLine : lines) {
            String line    = rawLine.trim();
            String lineUp  = line.toUpperCase(Locale.ROOT);

            // Título principal → ya en cabecera, omitir
            if (line.startsWith("CONTRATO DE ARRENDAMIENTO")) continue;

            // Bloque de firma (marcador especial :::)
            if (line.startsWith("EL ARRENDADOR:::") || line.startsWith("EL ARRENDATARIO:::")) {
                flushAccumulator(doc, accumulator, fontNormal);
                if (!inSignature) {
                    inSignature = true;
                    doc.add(new Paragraph(" ").setMarginBottom(4));
                    doc.add(new Table(1).useAllAvailableWidth()
                            .addCell(new Cell().setHeight(0.5f)
                                    .setBackgroundColor(GRAY).setBorder(Border.NO_BORDER))
                            .setMarginBottom(8));
                    doc.add(new Paragraph("FIRMAS DE LAS PARTES")
                            .setFont(fontBold).setFontSize(11).setFontColor(PURPLE)
                            .setMarginBottom(10));
                }
                String[] parts = line.split(":::");
                renderSignatureRow(doc, parts, fontNormal, fontBold);
                continue;
            }

            // Bloque de anexo
            if (line.startsWith("ANEXO I")) {
                flushAccumulator(doc, accumulator, fontNormal);
                inSignature = false;
                inAnexo     = true;
                doc.add(new AreaBreak());
                doc.add(new Paragraph(line)
                        .setFont(fontBold).setFontSize(12).setFontColor(PURPLE)
                        .setMarginBottom(10));
                continue;
            }

            // Confirmaciones del anexo (ARRENDADOR::: / ARRENDATARIO:::)
            if (inAnexo && (line.startsWith("ARRENDADOR:::") || line.startsWith("ARRENDATARIO:::"))) {
                flushAccumulator(doc, accumulator, fontNormal);
                String[] parts = line.split(":::");
                renderAnexoSignature(doc, parts, fontNormal, fontBold);
                continue;
            }

            // Marcadores de sección (REUNIDOS:, EXPONEN:, CLÁUSULAS:, FIRMA:)
            if (SECTION_MARKERS.contains(line)) {
                flushAccumulator(doc, accumulator, fontNormal);
                if (!line.equals("FIRMA:")) {
                    doc.add(new Paragraph(line)
                            .setFont(fontBold).setFontSize(11).setFontColor(PURPLE)
                            .setMarginTop(16).setMarginBottom(6));
                }
                continue;
            }

            // Títulos de cláusula: "PRIMERA - OBJETO", etc.
            if (isClauseTitle(line)) {
                flushAccumulator(doc, accumulator, fontNormal);
                String[] titleParts = line.split(" - ", 2);
                Paragraph clauseTitle = new Paragraph()
                        .add(new Text(titleParts[0]).setFont(fontBold).setFontColor(PURPLE))
                        .add(new Text(" — ").setFont(fontBold).setFontColor(GRAY))
                        .add(new Text(titleParts.length > 1 ? titleParts[1] : "")
                                .setFont(fontBold).setFontColor(DARK))
                        .setFontSize(10).setMarginTop(14).setMarginBottom(4);
                doc.add(clauseTitle);
                continue;
            }

            // Línea de ítem de inventario (empieza con "- ")
            if (inAnexo && line.startsWith("- ")) {
                flushAccumulator(doc, accumulator, fontNormal);
                doc.add(new Paragraph(line)
                        .setFont(fontNormal).setFontSize(10).setFontColor(DARK_GRAY)
                        .setMarginLeft(16).setMarginBottom(4));
                continue;
            }

            // Línea vacía → volcar párrafo acumulado
            if (line.isEmpty()) {
                flushAccumulator(doc, accumulator, fontNormal);
                continue;
            }

            // Texto normal → acumular
            if (accumulator.length() > 0) accumulator.append(" ");
            accumulator.append(line);
        }

        flushAccumulator(doc, accumulator, fontNormal);
    }

    // ── Volcar el acumulador como un párrafo justificado ─────────

    private static void flushAccumulator(Document doc, StringBuilder acc, PdfFont font) {
        String text = acc.toString().trim();
        if (!text.isEmpty()) {
            doc.add(new Paragraph(text)
                    .setFont(font).setFontSize(10).setFontColor(DARK_GRAY)
                    .setTextAlignment(TextAlignment.JUSTIFIED)
                    .setMarginBottom(6).setMultipliedLeading(1.3f));
        }
        acc.setLength(0);
    }

    // ── Fila de firma (dos columnas) ─────────────────────────────

    private static void renderSignatureRow(Document doc, String[] parts,
                                           PdfFont fontNormal, PdfFont fontBold) {
        // parts[0] = "EL ARRENDADOR" o "EL ARRENDATARIO", parts[1] = nombre, parts[2] = dni
        String rol    = parts.length > 0 ? parts[0] : "";
        String nombre = parts.length > 1 ? parts[1] : "";
        String dni    = parts.length > 2 ? parts[2] : "";

        doc.add(new Paragraph(rol)
                .setFont(fontBold).setFontSize(10).setFontColor(PURPLE)
                .setMarginTop(18).setMarginBottom(4));
        doc.add(new Paragraph(nombre)
                .setFont(fontNormal).setFontSize(10).setFontColor(DARK)
                .setMarginBottom(2));
        doc.add(new Paragraph(dni)
                .setFont(fontNormal).setFontSize(9).setFontColor(GRAY)
                .setMarginBottom(8));
        doc.add(new Paragraph("_______________________________")
                .setFont(fontNormal).setFontSize(10).setFontColor(DARK)
                .setMarginBottom(2));
        doc.add(new Paragraph("Firma y fecha")
                .setFont(fontNormal).setFontSize(9).setFontColor(GRAY)
                .setMarginBottom(14));
    }

    // ── Firma del anexo ──────────────────────────────────────────

    private static void renderAnexoSignature(Document doc, String[] parts,
                                              PdfFont fontNormal, PdfFont fontBold) {
        String rol    = parts.length > 0 ? parts[0] : "";
        String nombre = parts.length > 1 ? parts[1] : "";
        doc.add(new Paragraph(rol + ": " + nombre)
                .setFont(fontBold).setFontSize(10).setFontColor(DARK)
                .setMarginTop(12).setMarginBottom(4));
        doc.add(new Paragraph("_______________________________")
                .setFont(fontNormal).setFontSize(10).setFontColor(DARK)
                .setMarginBottom(2));
        doc.add(new Paragraph("Firma y fecha")
                .setFont(fontNormal).setFontSize(9).setFontColor(GRAY)
                .setMarginBottom(10));
    }

    // ── Detectar títulos de cláusula ─────────────────────────────

    private static boolean isClauseTitle(String line) {
        if (!line.contains(" - ")) return false;
        String firstWord = line.split(" - ")[0].trim();
        return ORDINALS.contains(firstWord.toUpperCase(Locale.ROOT));
    }

    // ── Pie de página con numeración ─────────────────────────────

    static class PageFooterHandler implements IEventHandler {
        private final PdfFont font;
        private final int idContrato;
        private final String descripcion;

        PageFooterHandler(PdfFont font, int idContrato, String descripcion) {
            this.font        = font;
            this.idContrato  = idContrato;
            this.descripcion = descripcion;
        }

        @Override
        public void handleEvent(Event event) {
            PdfDocumentEvent docEvent = (PdfDocumentEvent) event;
            PdfDocument pdfDoc = docEvent.getDocument();
            PdfPage     page   = docEvent.getPage();
            int pageNum        = pdfDoc.getPageNumber(page);
            Rectangle   rect   = page.getPageSize();

            try {
                PdfCanvas canvas = new PdfCanvas(page);

                // Línea separadora
                canvas.setLineWidth(0.3f)
                      .setStrokeColor(new DeviceRgb(108, 99, 255))
                      .moveTo(rect.getLeft()  + 72, 52)
                      .lineTo(rect.getRight() - 72, 52)
                      .stroke();

                // Texto izquierdo
                canvas.beginText()
                      .setFontAndSize(font, 8)
                      .setFillColor(new DeviceRgb(100, 100, 130))
                      .moveText(rect.getLeft() + 72, 40)
                      .showText("Contrato #" + idContrato
                              + "  —  GestionAp  —  " + descripcion)
                      .endText();

                // Texto derecho (número de página)
                String pageStr = "Pág. " + pageNum;
                canvas.beginText()
                      .setFontAndSize(font, 8)
                      .setFillColor(new DeviceRgb(108, 99, 255))
                      .moveText(rect.getRight() - 72 - 30, 40)
                      .showText(pageStr)
                      .endText()
                      .release();

            } catch (Exception ignored) {}
        }
    }

    // ── Utilidades ───────────────────────────────────────────────

    private static String nvl(String s) {
        return (s != null && !s.isBlank()) ? s : "—";
    }
}
