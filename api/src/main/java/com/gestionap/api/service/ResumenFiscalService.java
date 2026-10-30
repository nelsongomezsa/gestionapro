package com.gestionap.api.service;

import com.gestionap.api.domain.DatosPiso;
import com.gestionap.api.domain.Gasto.Categoria;
import com.gestionap.api.domain.Pago;
import com.gestionap.api.domain.Piso;
import com.gestionap.api.repository.PagoRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import com.gestionap.api.web.dto.GastoDtos.GastoResponse;
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
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;

/**
 * Resumen fiscal anual de un piso (IRPF, rendimientos del capital inmobiliario). ORIENTATIVO:
 * no sustituye a la declaración ni a un asesor. Reglas del Manual práctico de Renta 2025 de la
 * Agencia Tributaria (capítulo 4, rendimiento neto):
 * - Intereses, financiación, reparación y conservación no pueden superar los ingresos íntegros
 *   del inmueble; el exceso se puede deducir en los cuatro años siguientes.
 * - Amortización del inmueble: 3 % sobre el mayor entre el coste de adquisición de la
 *   construcción y el valor catastral de la construcción (sin el suelo, art. 14 RIRPF).
 * - Mobiliario cedido con el inmueble: según la tabla de la Orden de 27-3-1998 (10 % anual
 *   para mobiliario y enseres).
 * La reducción por arrendamiento de vivienda (art. 23.2 LIRPF) depende de cada contrato y del
 * uso como vivienda habitual: se informa, no se calcula.
 */
@Service
public class ResumenFiscalService {

    static final BigDecimal AMORTIZACION_INMUEBLE = new BigDecimal("0.03");
    static final BigDecimal AMORTIZACION_MOBILIARIO = new BigDecimal("0.10");
    private static final Set<Categoria> CON_LIMITE = EnumSet.of(Categoria.INTERESES, Categoria.REPARACION, Categoria.MANTENIMIENTO);

    public record Linea(String concepto, BigDecimal importe) {}

    public record Resumen(
            int anio,
            Integer idPiso,
            String piso,
            BigDecimal ingresos,
            int numeroPagos,
            List<Linea> gastosConLimite,
            BigDecimal gastosConLimiteAplicables,
            BigDecimal excesoParaAniosSiguientes,
            List<Linea> otrosGastos,
            BigDecimal amortizacionInmueble,
            String baseAmortizacion,
            BigDecimal amortizacionMobiliario,
            BigDecimal rendimientoNeto,
            List<String> notas) {}

    public record Archivo(String nombre, String tipo, byte[] contenido) {}

    private final ControlAcceso acceso;
    private final PagoRepository pagos;
    private final GastoService gastos;

    public ResumenFiscalService(ControlAcceso acceso, PagoRepository pagos, GastoService gastos) {
        this.acceso = acceso;
        this.pagos = pagos;
        this.gastos = gastos;
    }

    /** valorCatastral y valorCatastralConstruccion vienen del recibo del IBI (opcionales). */
    @Transactional
    public Resumen calcular(Integer idPiso, int anio, BigDecimal valorCatastral, BigDecimal valorCatastralConstruccion,
                            UsuarioAutenticado actor) {
        Piso piso = acceso.pisoVisible(idPiso, actor);
        LocalDate desde = LocalDate.of(anio, 1, 1);
        LocalDate hasta = LocalDate.of(anio, 12, 31);
        List<Pago> delAnio = pagos.buscar(piso.getPropietario().getId(), null, desde, hasta).stream()
                .filter(p -> p.getContrato().getHabitacion().getPiso().getId().equals(idPiso)).toList();
        BigDecimal ingresos = suma(delAnio.stream().map(Pago::getCantidad).toList());

        // Sincroniza las incidencias resueltas con coste y trae los gastos del año.
        List<GastoResponse> delAnioGastos = gastos.listar(idPiso, anio, actor).lista().stream().filter(GastoResponse::deducible).toList();
        List<Linea> conLimite = porCategoria(delAnioGastos, CON_LIMITE);
        Set<Categoria> resto = EnumSet.complementOf(EnumSet.copyOf(CON_LIMITE));
        resto.remove(Categoria.MOBILIARIO);
        List<Linea> otros = porCategoria(delAnioGastos, resto);
        BigDecimal totalConLimite = suma(conLimite.stream().map(Linea::importe).toList());
        BigDecimal aplicables = totalConLimite.min(ingresos);
        BigDecimal exceso = totalConLimite.subtract(aplicables);

        List<String> notas = new ArrayList<>();
        notas.add("Orientativo: no sustituye a la declaración de la renta ni al consejo de un asesor fiscal.");
        notas.add("Ingresos: pagos registrados en el año. Hacienda usa las rentas devengadas: revisa los pagos atrasados o adelantados.");

        DatosPiso d = piso.getDatosFinancieros();
        BigDecimal amortInmueble = null;
        String base;
        if (d == null) {
            base = "Faltan los datos de compra del piso.";
        } else if (valorCatastral == null || valorCatastralConstruccion == null || valorCatastral.signum() <= 0) {
            base = "Indica el valor catastral y el de la construcción (recibo del IBI) para calcularla.";
        } else {
            BigDecimal proporcion = valorCatastralConstruccion.divide(valorCatastral, 6, RoundingMode.HALF_UP);
            BigDecimal coste = nz(d.getPrecioCompra()).add(nz(d.getItpPagado())).add(nz(d.getGastosNotaria()))
                    .add(nz(d.getGastosRegistro())).add(nz(d.getOtrosGastosCompra())).add(nz(d.getCosteReforma()));
            BigDecimal costeConstruccion = coste.multiply(proporcion).setScale(2, RoundingMode.HALF_UP);
            boolean porCoste = costeConstruccion.compareTo(valorCatastralConstruccion) >= 0;
            BigDecimal baseImporte = porCoste ? costeConstruccion : valorCatastralConstruccion;
            amortInmueble = baseImporte.multiply(AMORTIZACION_INMUEBLE).setScale(2, RoundingMode.HALF_UP);
            base = "3 % de " + Textos.euros(baseImporte) + (porCoste
                    ? " (coste de adquisición de la construcción: el " + proporcion.movePointRight(2).setScale(1, RoundingMode.HALF_UP)
                      .toPlainString() + " % del coste total, según el reparto del valor catastral)"
                    : " (valor catastral de la construcción)");
            notas.add("Si el piso no estuvo alquilado todo el año, la amortización se prorratea por los días alquilados.");
        }
        BigDecimal baseMuebles = (d == null ? BigDecimal.ZERO : nz(d.getCosteMobiliario()))
                .add(suma(delAnioGastos.stream().filter(g -> g.categoria() == Categoria.MOBILIARIO).map(GastoResponse::importe).toList()));
        BigDecimal amortMuebles = baseMuebles.multiply(AMORTIZACION_MOBILIARIO).setScale(2, RoundingMode.HALF_UP);
        if (exceso.signum() > 0) {
            notas.add("Intereses, reparación y conservación superan los ingresos: " + Textos.euros(exceso)
                    + " se pueden deducir en los cuatro años siguientes.");
        }
        notas.add("Reducción por alquiler de vivienda (art. 23.2 LIRPF): si es vivienda habitual del inquilino, el rendimiento "
                + "neto positivo puede reducirse (60 % en contratos anteriores al 26-05-2023; desde entonces, 50 % con carácter "
                + "general y más en algunos casos). No se aplica aquí: depende de cada contrato.");
        notas.add("Fuente: Agencia Tributaria, Manual práctico de Renta 2025, capítulo 4 (rendimientos del capital inmobiliario).");

        BigDecimal neto = ingresos.subtract(aplicables).subtract(suma(otros.stream().map(Linea::importe).toList()))
                .subtract(amortInmueble == null ? BigDecimal.ZERO : amortInmueble).subtract(amortMuebles);
        return new Resumen(anio, idPiso, piso.getDireccion() + ", " + piso.getCiudad().getNombre(), ingresos, delAnio.size(),
                conLimite, aplicables, exceso, otros, amortInmueble, base, amortMuebles, neto, notas);
    }

    /** Hoja de cálculo: ";" y coma decimal, como la abre Excel en español. */
    public Archivo csv(Resumen r) {
        StringBuilder s = new StringBuilder("﻿Concepto;Importe\n");
        fila(s, "Ingresos íntegros (" + r.numeroPagos() + " pagos)", r.ingresos());
        r.gastosConLimite().forEach(l -> fila(s, l.concepto(), l.importe().negate()));
        if (r.excesoParaAniosSiguientes().signum() > 0) fila(s, "Exceso para los 4 años siguientes", r.excesoParaAniosSiguientes());
        r.otrosGastos().forEach(l -> fila(s, l.concepto(), l.importe().negate()));
        if (r.amortizacionInmueble() != null) fila(s, "Amortización del inmueble", r.amortizacionInmueble().negate());
        fila(s, "Amortización del mobiliario", r.amortizacionMobiliario().negate());
        fila(s, "Rendimiento neto (orientativo)", r.rendimientoNeto());
        return new Archivo("Resumen-fiscal-" + r.anio() + "-piso" + r.idPiso() + ".csv", "text/csv",
                s.toString().getBytes(StandardCharsets.UTF_8));
    }

    public Archivo pdf(Resumen r) {
        DeviceRgb marino = new DeviceRgb(15, 27, 51);
        DeviceRgb azul = new DeviceRgb(31, 95, 224);
        DeviceRgb gris = new DeviceRgb(91, 100, 117);
        ByteArrayOutputStream salida = new ByteArrayOutputStream();
        try (PdfDocument pdf = new PdfDocument(new PdfWriter(salida)); Document doc = new Document(pdf, PageSize.A4)) {
            PdfFont normal = PdfFontFactory.createFont(StandardFonts.HELVETICA);
            PdfFont negrita = PdfFontFactory.createFont(StandardFonts.HELVETICA_BOLD);
            doc.setMargins(48, 48, 48, 48);
            doc.add(new Paragraph("GestionAp").setFont(negrita).setFontSize(11).setFontColor(azul));
            doc.add(new Paragraph("RESUMEN FISCAL " + r.anio() + " · ORIENTATIVO").setFont(negrita).setFontSize(18).setFontColor(marino));
            doc.add(new Paragraph(r.piso()).setFont(normal).setFontSize(10).setMarginBottom(14));
            Table t = new Table(UnitValue.createPercentArray(new float[]{4, 1.4f})).useAllAvailableWidth();
            fila(t, "Ingresos íntegros (" + r.numeroPagos() + " pagos)", r.ingresos(), negrita, normal);
            r.gastosConLimite().forEach(l -> fila(t, l.concepto(), l.importe().negate(), normal, normal));
            if (r.excesoParaAniosSiguientes().signum() > 0) {
                fila(t, "  Exceso sobre los ingresos (para los 4 años siguientes)", r.excesoParaAniosSiguientes(), normal, normal);
            }
            r.otrosGastos().forEach(l -> fila(t, l.concepto(), l.importe().negate(), normal, normal));
            if (r.amortizacionInmueble() != null) fila(t, "Amortización del inmueble", r.amortizacionInmueble().negate(), normal, normal);
            fila(t, "Amortización del mobiliario (10 %)", r.amortizacionMobiliario().negate(), normal, normal);
            Cell c1 = new Cell().add(new Paragraph("Rendimiento neto").setFont(negrita).setFontSize(11)).setBorder(Border.NO_BORDER)
                    .setBorderTop(new SolidBorder(gris, 0.5f)).setPaddingTop(6);
            Cell c2 = new Cell().add(new Paragraph(Textos.euros(r.rendimientoNeto())).setFont(negrita).setFontSize(11)
                    .setTextAlignment(TextAlignment.RIGHT)).setBorder(Border.NO_BORDER).setBorderTop(new SolidBorder(gris, 0.5f)).setPaddingTop(6);
            t.addCell(c1);
            t.addCell(c2);
            doc.add(t.setMarginBottom(10));
            doc.add(new Paragraph("Base de la amortización: " + r.baseAmortizacion()).setFont(normal).setFontSize(8).setFontColor(gris));
            for (String n : r.notas()) doc.add(new Paragraph("· " + n).setFont(normal).setFontSize(8).setFontColor(gris).setMarginBottom(0));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        return new Archivo("Resumen-fiscal-" + r.anio() + "-piso" + r.idPiso() + ".pdf", "application/pdf", salida.toByteArray());
    }

    private static void fila(Table t, String concepto, BigDecimal importe, PdfFont fConcepto, PdfFont fImporte) {
        t.addCell(new Cell().add(new Paragraph(concepto).setFont(fConcepto).setFontSize(10)).setBorder(Border.NO_BORDER).setPadding(3));
        t.addCell(new Cell().add(new Paragraph(Textos.euros(importe)).setFont(fImporte).setFontSize(10).setTextAlignment(TextAlignment.RIGHT))
                .setBorder(Border.NO_BORDER).setPadding(3));
    }

    private static void fila(StringBuilder s, String concepto, BigDecimal importe) {
        s.append('"').append(concepto.replace("\"", "\"\"")).append("\";").append(importe.setScale(2, RoundingMode.HALF_UP)
                .toPlainString().replace('.', ',')).append('\n');
    }

    private static List<Linea> porCategoria(List<GastoResponse> lista, Set<Categoria> categorias) {
        List<Linea> lineas = new ArrayList<>();
        for (Categoria c : categorias) {
            BigDecimal total = suma(lista.stream().filter(g -> g.categoria() == c).map(GastoResponse::importe).toList());
            if (total.signum() > 0) lineas.add(new Linea(nombre(c), total));
        }
        return lineas;
    }

    static String nombre(Categoria c) {
        return switch (c) {
            case COMUNIDAD -> "Comunidad de propietarios";
            case IBI -> "IBI y otros tributos";
            case SEGURO -> "Seguros";
            case SUMINISTROS -> "Suministros";
            case REPARACION -> "Reparación";
            case MANTENIMIENTO -> "Conservación y mantenimiento";
            case MOBILIARIO -> "Mobiliario";
            case INTERESES -> "Intereses de financiación";
            case GESTION -> "Gestoría y administración";
            case OTROS -> "Otros gastos";
        };
    }

    private static BigDecimal suma(List<BigDecimal> l) {
        return l.stream().reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }
}
