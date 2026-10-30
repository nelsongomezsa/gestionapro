package com.gestionap.api.service;

import com.gestionap.api.domain.Contrato;
import com.gestionap.api.domain.Habitacion;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.HabitacionRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.dto.PisoResponse;
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
import java.math.BigDecimal;
import java.text.NumberFormat;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

/** Ficha del piso en PDF (exportar del detalle de piso del escritorio): métricas, habitaciones y contratos. */
@Service
public class FichaPisoPdf {

    private static final DeviceRgb MORADO = new DeviceRgb(108, 99, 255);
    private static final DeviceRgb GRIS = new DeviceRgb(100, 100, 130);
    private static final DeviceRgb FONDO = new DeviceRgb(245, 245, 252);
    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final PisoService pisos;
    private final HabitacionRepository habitaciones;
    private final ContratoRepository contratos;

    public FichaPisoPdf(PisoService pisos, HabitacionRepository habitaciones, ContratoRepository contratos) {
        this.pisos = pisos;
        this.habitaciones = habitaciones;
        this.contratos = contratos;
    }

    public record Ficha(String nombreArchivo, byte[] contenido) {}

    @Transactional(readOnly = true)
    public Ficha generar(Integer idPiso, UsuarioAutenticado actor) {
        PisoResponse p = pisos.obtener(idPiso, actor);
        List<Habitacion> habs = habitaciones.buscar(null, idPiso, null);
        LocalDate hoy = LocalDate.now();
        List<Contrato> activos = contratos.buscar(null, null, idPiso).stream().filter(c -> c.estaActivoEn(hoy)).toList();
        NumberFormat euros = NumberFormat.getCurrencyInstance(Textos.ES);

        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        try (PdfDocument pdf = new PdfDocument(new PdfWriter(salida)); Document doc = new Document(pdf, PageSize.A4)) {
            PdfFont normal = PdfFontFactory.createFont(StandardFonts.HELVETICA);
            PdfFont negrita = PdfFontFactory.createFont(StandardFonts.HELVETICA_BOLD);
            doc.setMargins(48, 48, 48, 48);
            doc.add(new Paragraph("GestionAp · Ficha del piso").setFont(negrita).setFontSize(11).setFontColor(MORADO));
            doc.add(new Paragraph(p.direccion()).setFont(negrita).setFontSize(20).setMarginBottom(0));
            doc.add(new Paragraph(p.ciudad().nombre() + " · generado el " + hoy.format(FECHA))
                    .setFont(normal).setFontSize(9).setFontColor(GRIS).setMarginBottom(16));

            seccion(doc, "RESUMEN", negrita);
            Table r = new Table(UnitValue.createPercentArray(new float[]{3, 2})).useAllAvailableWidth();
            fila(r, "Habitaciones", String.valueOf(p.ocupacion().total()), normal, negrita);
            fila(r, "Alquiladas / disponibles / mantenimiento",
                    p.ocupacion().alquiladas() + " / " + p.ocupacion().disponibles() + " / " + p.ocupacion().mantenimiento(), normal, negrita);
            fila(r, "Ingresos mensuales (contratos activos)", euros.format(p.ingresosMensuales()), normal, negrita);
            var m = p.metricas();
            if (m != null) {
                fila(r, "Inversión total", euros.format(m.inversionTotal()), normal, negrita);
                fila(r, "Capital propio", euros.format(m.capitalPropio()), normal, negrita);
                fila(r, "Cuota de hipoteca", euros.format(m.cuotaMensualHipoteca()), normal, negrita);
                fila(r, "Gastos anuales", euros.format(m.gastosAnuales()), normal, negrita);
                fila(r, "Cash flow mensual", euros.format(m.cashFlowMensual()), normal, negrita);
                fila(r, "Rentabilidad bruta / neta", pct(m.rentabilidadBrutaPct()) + " / " + pct(m.rentabilidadNetaPct()), normal, negrita);
                fila(r, "Cash-on-cash", pct(m.cashOnCashPct()), normal, negrita);
                fila(r, "Plusvalía latente", euros.format(m.plusvaliaLatente()), normal, negrita);
            }
            doc.add(r.setMarginBottom(16));

            seccion(doc, "HABITACIONES", negrita);
            Table th = cabecera(new float[]{1, 1.5f, 2}, negrita, "HAB.", "PRECIO", "ESTADO");
            for (Habitacion h : habs) {
                th.addCell(celda(String.valueOf(h.getNumero()), normal, false));
                th.addCell(celda(euros.format(h.getPrecio()), normal, true));
                th.addCell(celda(h.getEstado().name(), normal, false));
            }
            doc.add(th.setMarginBottom(16));

            seccion(doc, "CONTRATOS ACTIVOS", negrita);
            if (activos.isEmpty()) {
                doc.add(new Paragraph("Sin contratos activos.").setFont(normal).setFontSize(10).setFontColor(GRIS));
            } else {
                Table tc = cabecera(new float[]{2.5f, 1, 1.5f, 1.5f}, negrita, "INQUILINO", "HAB.", "€/MES", "FIN");
                BigDecimal total = BigDecimal.ZERO;
                for (Contrato c : activos) {
                    tc.addCell(celda(c.getInquilino().getNombreCompleto(), normal, false));
                    tc.addCell(celda(String.valueOf(c.getHabitacion().getNumero()), normal, false));
                    tc.addCell(celda(euros.format(c.getPrecioMensual()), normal, true));
                    tc.addCell(celda(c.getFechaFin().format(FECHA), normal, false));
                    total = total.add(c.getPrecioMensual());
                }
                tc.addCell(celda("TOTAL", negrita, false));
                tc.addCell(celda("", normal, false));
                tc.addCell(celda(euros.format(total), negrita, true));
                tc.addCell(celda("", normal, false));
                doc.add(tc);
            }
        } catch (IOException e) {
            throw new UncheckedIOException("No se pudo generar la ficha del piso", e);
        }
        return new Ficha("Piso_" + p.direccion().replaceAll("[^\\p{L}\\p{N}]+", "_") + ".pdf", salida.toByteArray());
    }

    private static String pct(Double v) {
        return v == null ? "—" : String.format(Textos.ES, "%.2f %%", v);
    }

    private static void seccion(Document doc, String titulo, PdfFont fuente) {
        doc.add(new Paragraph(titulo).setFont(fuente).setFontSize(11).setFontColor(MORADO).setMarginBottom(6));
    }

    private static void fila(Table t, String etiqueta, String valor, PdfFont normal, PdfFont negrita) {
        t.addCell(celda(etiqueta, normal, false));
        t.addCell(celda(valor, negrita, true));
    }

    private static Table cabecera(float[] anchos, PdfFont fuente, String... titulos) {
        Table t = new Table(UnitValue.createPercentArray(anchos)).useAllAvailableWidth();
        for (String h : titulos) {
            t.addHeaderCell(new Cell().add(new Paragraph(h).setFont(fuente).setFontSize(8).setFontColor(MORADO))
                    .setBackgroundColor(FONDO).setBorder(Border.NO_BORDER).setPadding(5));
        }
        return t;
    }

    private static Cell celda(String texto, PdfFont fuente, boolean derecha) {
        Paragraph p = new Paragraph(texto).setFont(fuente).setFontSize(9);
        if (derecha) p.setTextAlignment(TextAlignment.RIGHT);
        return new Cell().add(p).setBorder(Border.NO_BORDER)
                .setBorderBottom(new SolidBorder(new DeviceRgb(230, 230, 240), 0.5f)).setPadding(5);
    }
}
