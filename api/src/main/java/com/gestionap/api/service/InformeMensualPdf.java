package com.gestionap.api.service;

import com.gestionap.api.domain.*;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.IncidenciaRepository;
import com.gestionap.api.repository.PagoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.dto.PanelDtos;
import com.gestionap.api.web.dto.ResumenPagosResponse;
import com.itextpdf.io.font.constants.StandardFonts;
import com.itextpdf.kernel.colors.DeviceRgb;
import com.itextpdf.kernel.font.PdfFont;
import com.itextpdf.kernel.font.PdfFontFactory;
import com.itextpdf.kernel.geom.PageSize;
import com.itextpdf.kernel.pdf.PdfDocument;
import com.itextpdf.kernel.pdf.PdfWriter;
import com.itextpdf.layout.Document;
import com.itextpdf.layout.borders.Border;
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
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.Comparator;
import java.util.List;
import java.util.Set;

/**
 * Informe mensual en PDF (DashboardController.generarInformePDF del escritorio): resumen
 * ejecutivo, contratos activos, pagos del mes e incidencias pendientes, solo con los datos
 * del propietario. Se devuelve en la respuesta en vez de guardarse en el Escritorio.
 */
@Service
public class InformeMensualPdf {

    private static final DeviceRgb MORADO = new DeviceRgb(108, 99, 255);
    private static final DeviceRgb GRIS = new DeviceRgb(100, 100, 130);
    private static final DeviceRgb FONDO = new DeviceRgb(245, 245, 252);
    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final ContratoRepository contratos;
    private final PagoRepository pagos;
    private final IncidenciaRepository incidencias;
    private final PagoService pagoService;
    private final PanelService panel;
    private final ControlAcceso acceso;

    public InformeMensualPdf(ContratoRepository contratos, PagoRepository pagos, IncidenciaRepository incidencias,
                             PagoService pagoService, PanelService panel, ControlAcceso acceso) {
        this.contratos = contratos;
        this.pagos = pagos;
        this.incidencias = incidencias;
        this.pagoService = pagoService;
        this.panel = panel;
        this.acceso = acceso;
    }

    public record Informe(String nombreArchivo, byte[] contenido) {}

    @Transactional(readOnly = true)
    public Informe generar(YearMonth mes, UsuarioAutenticado actor) {
        Integer prop = acceso.filtroPropietario(actor);
        ResumenPagosResponse resumen = pagoService.resumen(mes, actor);
        PanelDtos.Ocupacion ocupacion = panel.ocupacion(prop);
        LocalDate inicio = mes.atDay(1);
        LocalDate fin = mes.atEndOfMonth();
        List<Contrato> vigentes = contratos.buscar(prop, null, null).stream()
                .filter(c -> !c.getFechaInicio().isAfter(fin) && !c.getFechaFin().isBefore(inicio))
                .sorted(Comparator.comparing((Contrato c) -> c.getInquilino().getApellidos())).toList();
        List<Pago> delMes = pagos.buscar(prop, null, inicio, fin).stream()
                .sorted(Comparator.comparing(Pago::getFechaPago)).toList();
        List<Incidencia> pendientes = incidencias.buscar(prop, null, null,
                Set.of(EstadoIncidencia.pendiente, EstadoIncidencia.en_proceso));
        String nombreMes = Textos.mes(mes);
        NumberFormat euros = NumberFormat.getCurrencyInstance(Textos.ES);

        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        try (PdfDocument pdf = new PdfDocument(new PdfWriter(salida)); Document doc = new Document(pdf, PageSize.A4)) {
            PdfFont normal = PdfFontFactory.createFont(StandardFonts.HELVETICA);
            PdfFont negrita = PdfFontFactory.createFont(StandardFonts.HELVETICA_BOLD);
            doc.setMargins(48, 48, 48, 48);

            doc.add(new Paragraph("GestionAp").setFont(negrita).setFontSize(12).setFontColor(MORADO));
            doc.add(new Paragraph("INFORME MENSUAL · " + nombreMes.toUpperCase(Textos.ES))
                    .setFont(negrita).setFontSize(20).setMarginBottom(2));
            doc.add(new Paragraph("Generado el " + LocalDate.now().format(FECHA) + " para " + actor.nombre())
                    .setFont(normal).setFontSize(9).setFontColor(GRIS).setMarginBottom(16));

            seccion(doc, "RESUMEN EJECUTIVO", negrita);
            Table t = new Table(UnitValue.createPercentArray(new float[]{3, 2})).useAllAvailableWidth();
            String[][] filas = {
                    {"Habitaciones totales", String.valueOf(ocupacion.habitaciones())},
                    {"Habitaciones alquiladas", String.valueOf(ocupacion.alquiladas())},
                    {"Tasa de ocupación", String.format(Textos.ES, "%.1f %%", ocupacion.porcentaje())},
                    {"Contratos activos en el mes", String.valueOf(vigentes.size())},
                    {"Ingresos esperados", euros.format(resumen.esperado())},
                    {"Ingresos cobrados", euros.format(resumen.cobrado())},
                    {"Pendiente de cobro", euros.format(resumen.pendiente())},
                    {"Incidencias pendientes", String.valueOf(pendientes.size())},
            };
            for (String[] f : filas) {
                t.addCell(celda(f[0], normal, false));
                t.addCell(celda(f[1], negrita, true));
            }
            doc.add(t.setMarginBottom(16));

            seccion(doc, "CONTRATOS ACTIVOS", negrita);
            if (vigentes.isEmpty()) {
                vacio(doc, "Sin contratos activos en este mes.", normal);
            } else {
                Table tc = cabecera(new float[]{2.5f, 1, 2.5f, 1.2f, 1.5f}, negrita, "INQUILINO", "HAB.", "DIRECCIÓN", "€/MES", "FIN CONTRATO");
                for (Contrato c : vigentes) {
                    tc.addCell(celda(c.getInquilino().getNombreCompleto(), normal, false));
                    tc.addCell(celda(String.valueOf(c.getHabitacion().getNumero()), normal, false));
                    tc.addCell(celda(c.getHabitacion().getPiso().getDireccion(), normal, false));
                    tc.addCell(celda(euros.format(c.getPrecioMensual()), normal, true));
                    tc.addCell(celda(c.getFechaFin().format(FECHA), normal, false));
                }
                doc.add(tc.setMarginBottom(16));
            }

            seccion(doc, "PAGOS REGISTRADOS EN " + nombreMes.toUpperCase(Textos.ES), negrita);
            if (delMes.isEmpty()) {
                vacio(doc, "Sin pagos registrados en este mes.", normal);
            } else {
                Table tp = cabecera(new float[]{2.5f, 1.2f, 1.5f, 1.5f}, negrita, "INQUILINO", "CANTIDAD", "MÉTODO", "FECHA");
                for (Pago p : delMes) {
                    tp.addCell(celda(p.getContrato().getInquilino().getNombreCompleto(), normal, false));
                    tp.addCell(celda(euros.format(p.getCantidad()), normal, true));
                    tp.addCell(celda(p.getMetodoPago().name(), normal, false));
                    tp.addCell(celda(p.getFechaPago().format(FECHA), normal, false));
                }
                BigDecimal total = delMes.stream().map(Pago::getCantidad).reduce(BigDecimal.ZERO, BigDecimal::add);
                tp.addCell(celda("TOTAL", negrita, false));
                tp.addCell(celda(euros.format(total), negrita, true));
                tp.addCell(celda("", normal, false));
                tp.addCell(celda("", normal, false));
                doc.add(tp.setMarginBottom(16));
            }

            seccion(doc, "INCIDENCIAS PENDIENTES", negrita);
            if (pendientes.isEmpty()) {
                vacio(doc, "Sin incidencias pendientes.", normal);
            } else {
                Table ti = cabecera(new float[]{3f, 1f, 2f, 1.5f}, negrita, "DESCRIPCIÓN", "HAB.", "INQUILINO", "FECHA");
                for (Incidencia i : pendientes) {
                    ti.addCell(celda(i.getDescripcion(), normal, false));
                    ti.addCell(celda(String.valueOf(i.getHabitacion().getNumero()), normal, false));
                    ti.addCell(celda(i.getInquilino().getNombreCompleto(), normal, false));
                    ti.addCell(celda(i.getFecha().format(FECHA), normal, false));
                }
                doc.add(ti);
            }
        } catch (IOException e) {
            throw new UncheckedIOException("No se pudo generar el informe mensual", e);
        }
        return new Informe("Informe_" + mes + ".pdf", salida.toByteArray());
    }

    private static void seccion(Document doc, String titulo, PdfFont fuente) {
        doc.add(new Paragraph(titulo).setFont(fuente).setFontSize(11).setFontColor(MORADO).setMarginBottom(6));
    }

    private static void vacio(Document doc, String texto, PdfFont fuente) {
        doc.add(new Paragraph(texto).setFont(fuente).setFontSize(10).setFontColor(GRIS).setMarginBottom(16));
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
        return new Cell().add(p).setBorder(Border.NO_BORDER).setBorderBottom(
                new com.itextpdf.layout.borders.SolidBorder(new DeviceRgb(230, 230, 240), 0.5f)).setPadding(5);
    }
}
