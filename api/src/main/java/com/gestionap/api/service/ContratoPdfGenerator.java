package com.gestionap.api.service;

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
            BigDecimal precioMensual) {}

    private static final String PLANTILLA = "/plantillas/plantilla_contrato.txt";

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
        try (InputStream is = ContratoPdfGenerator.class.getResourceAsStream(PLANTILLA)) {
            if (is == null)
                throw new IllegalStateException("No se encontró " + PLANTILLA + " en recursos.");
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
                .replace("{{FIANZA}}",              d.precioMensual().toPlainString())
                .replace("{{SUMINISTROS_INCLUIDOS}}", "La renta incluye agua, electricidad e internet.")
                .replace("{{FECHA_HOY}}",           LocalDate.now().format(FMT_ES));

        try {
            PdfFont fontNormal = PdfFontFactory.createFont(StandardFonts.HELVETICA);
            PdfFont fontBold   = PdfFontFactory.createFont(StandardFonts.HELVETICA_BOLD);

            ByteArrayOutputStream salida = new ByteArrayOutputStream();
            PdfDocument pdf = new PdfDocument(new PdfWriter(salida));
            pdf.addEventHandler(PdfDocumentEvent.END_PAGE,
                    new PageFooterHandler(fontNormal, d.idContrato()));

            // Márgenes: 2.54 cm ≈ 72 pt
            Document doc = new Document(pdf, PageSize.A4);
            doc.setMargins(72, 72, 72, 72);

            renderPdf(doc, texto, fontNormal, fontBold, direccion, ciudad,
                      nombreInq, dniInq);

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
                                  String nombreInq, String dniInq) {
        // ── Cabecera del documento ──
        doc.add(new Paragraph("CONTRATO DE ARRENDAMIENTO")
                .setFont(fontBold).setFontSize(16).setFontColor(PURPLE)
                .setTextAlignment(TextAlignment.CENTER).setMarginBottom(2));
        doc.add(new Paragraph("DE HABITACIÓN EN PISO COMPARTIDO")
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

        PageFooterHandler(PdfFont font, int idContrato) {
            this.font       = font;
            this.idContrato = idContrato;
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
                              + "  —  GestionAp  —  Arrendamiento de habitación en piso compartido")
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
