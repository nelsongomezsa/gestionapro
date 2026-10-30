import Charts
import SwiftUI

struct ResultadoRentabilidadView: View {
    let resultado: RentabilidadResponse
    let comunidad: String
    @State private var documento: DocumentoPDF?

    var body: some View {
        let r = resultado
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Tema.Espacio.s), GridItem(.flexible(), spacing: Tema.Espacio.s)],
                          spacing: Tema.Espacio.s) {
                    TarjetaKPI(titulo: "Rentabilidad bruta", valor: Formato.porcentaje(r.rentabilidadBrutaPct), icono: "percent")
                    TarjetaKPI(titulo: "Rentabilidad neta", valor: Formato.porcentaje(r.rentabilidadNetaPct),
                               icono: "chart.line.uptrend.xyaxis", tono: Tono.signo(r.rentabilidadNetaPct.double))
                    TarjetaKPI(titulo: "Cash flow previsto", valor: Formato.euros(r.cashFlowMensual),
                               icono: "arrow.left.arrow.right", tono: Tono.signo(r.cashFlowMensual))
                    TarjetaKPI(titulo: "Recuperas la inversión", valor: Formato.anios(r.aniosRecuperacion), icono: "hourglass",
                               tono: .neutro)
                }

                seccion("¿A dónde va el alquiler?") {
                    DestinoAlquilerChart(resultado: r)
                        .frame(height: 200)
                    Text("Importes mensuales previstos. El cash flow es lo que queda tras la cuota y los gastos.")
                        .font(Tema.Fuente.nota)
                        .foregroundStyle(Tema.Color.textoSecundario)
                }

                seccion("Compra") {
                    FilaMetrica(titulo: "ITP \(comunidad) (\(Formato.porcentaje(r.itpPct)))", valor: Formato.euros(r.itpImporte))
                    Divider()
                    FilaMetrica(titulo: "Total compra", valor: Formato.euros(r.totalCompra))
                }
                seccion("Financiación") {
                    FilaMetrica(titulo: "Hipoteca", valor: Formato.euros(r.hipoteca))
                    Divider()
                    FilaMetrica(titulo: "Capital aportado", valor: Formato.euros(r.capitalAportado))
                    Divider()
                    FilaMetrica(titulo: "Cuota mensual", valor: Formato.euros(r.cuotaMensual))
                    Divider()
                    FilaMetrica(titulo: "Intereses", valor: Formato.euros(r.interesesMensualesPromedio), nota: "Media mensual")
                    Divider()
                    FilaMetrica(titulo: "Amortización", valor: Formato.euros(r.amortizacionMensualPromedio), nota: "Media mensual")
                }
                seccion("Gastos e ingresos") {
                    FilaMetrica(titulo: "Gastos mensuales", valor: Formato.euros(r.gastosMensuales))
                    Divider()
                    FilaMetrica(titulo: "Gastos anuales", valor: Formato.euros(r.gastosAnuales))
                    Divider()
                    FilaMetrica(titulo: "Alquiler anual", valor: Formato.euros(r.alquilerAnual))
                    Divider()
                    FilaMetrica(titulo: "Cash flow anual", valor: Formato.euros(r.cashFlowAnual), tono: Tono.signo(r.cashFlowAnual))
                }
                if r.plusvalia5Anios != nil || r.plusvalia10Anios != nil {
                    seccion("Revalorización estimada") {
                        FilaMetrica(titulo: "Plusvalía a 5 años", valor: Formato.euros(r.plusvalia5Anios))
                        Divider()
                        FilaMetrica(titulo: "Plusvalía a 10 años", valor: Formato.euros(r.plusvalia10Anios))
                    }
                }
            }
            .padding(Tema.Espacio.m)
        }
        .background(Tema.Color.fondo)
        .navigationTitle("Desglose")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Exportar PDF", systemImage: "doc.richtext") { documento = pdf() }
            }
        }
        .visorPDF($documento)
    }

    private func seccion<Contenido: View>(_ titulo: String, @ViewBuilder contenido: () -> Contenido) -> some View {
        SeccionTarjeta(titulo: titulo, contenido: contenido)
    }
}

/// Barras: alquiler mensual frente a cuota, gastos y el cash flow resultante.
struct DestinoAlquilerChart: View {
    let resultado: RentabilidadResponse

    struct Barra: Identifiable {
        let concepto: String
        let importe: Double
        let color: Color
        var id: String { concepto }
    }

    var barras: [Barra] {
        let cashFlow = resultado.cashFlowMensual.double
        return [
            Barra(concepto: "Alquiler", importe: resultado.alquilerAnual.double / 12, color: Tema.Color.primario),
            Barra(concepto: "Cuota", importe: resultado.cuotaMensual.double, color: Tema.Color.aviso),
            Barra(concepto: "Gastos", importe: resultado.gastosMensuales.double, color: Tema.Color.neutro),
            Barra(concepto: "Cash flow", importe: cashFlow, color: cashFlow < 0 ? Tema.Color.negativo : Tema.Color.positivo),
        ]
    }

    var body: some View {
        Chart(barras) { barra in
            BarMark(x: .value("Concepto", barra.concepto), y: .value("€/mes", barra.importe))
                .foregroundStyle(barra.color)
                .clipShape(.rect(cornerRadius: Tema.Radio.pequeno / 2))
                .accessibilityLabel(barra.concepto)
                .accessibilityValue("\(Formato.eurosRedondo(barra.importe)) al mes")
                .annotation(position: barra.importe < 0 ? .bottom : .top) {
                    Text(Formato.eurosRedondo(barra.importe))
                        .font(Tema.Fuente.nota.monospacedDigit())
                        .foregroundStyle(Tema.Color.textoSecundario)
                }
        }
        .chartYAxis {
            AxisMarks { valor in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(Tema.Color.borde)
                AxisValueLabel {
                    if let v = valor.as(Double.self) { Text(Formato.eurosRedondo(v)) }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
        }
        .accessibilityLabel("Gráfico del destino del alquiler mensual")
    }
}

extension ResultadoRentabilidadView {
    /// Resultado en PDF (como "Exportar PDF" de la calculadora del escritorio), generado en el móvil.
    func pdf() -> DocumentoPDF {
        let r = resultado
        var secciones: [(String, [(String, String)])] = [
            ("Rentabilidad", [
                ("Rentabilidad bruta", Formato.porcentaje(r.rentabilidadBrutaPct)),
                ("Rentabilidad neta", Formato.porcentaje(r.rentabilidadNetaPct)),
                ("Cash flow mensual", Formato.euros(r.cashFlowMensual)),
                ("Cash flow anual", Formato.euros(r.cashFlowAnual)),
                ("Años para recuperar", Formato.anios(r.aniosRecuperacion)),
            ]),
            ("Coste de compra", [
                ("ITP \(comunidad) (\(Formato.porcentaje(r.itpPct)))", Formato.euros(r.itpImporte)),
                ("Total compra", Formato.euros(r.totalCompra)),
            ]),
            ("Financiación", [
                ("Hipoteca", Formato.euros(r.hipoteca)),
                ("Capital aportado", Formato.euros(r.capitalAportado)),
                ("Cuota mensual", Formato.euros(r.cuotaMensual)),
                ("Intereses (media mensual)", Formato.euros(r.interesesMensualesPromedio)),
                ("Amortización (media mensual)", Formato.euros(r.amortizacionMensualPromedio)),
            ]),
            ("Gastos e ingresos", [
                ("Gastos mensuales", Formato.euros(r.gastosMensuales)),
                ("Gastos anuales", Formato.euros(r.gastosAnuales)),
                ("Alquiler anual", Formato.euros(r.alquilerAnual)),
            ]),
        ]
        if r.plusvalia5Anios != nil || r.plusvalia10Anios != nil {
            secciones.append(("Revalorización estimada", [
                ("Plusvalía a 5 años", Formato.euros(r.plusvalia5Anios)),
                ("Plusvalía a 10 años", Formato.euros(r.plusvalia10Anios)),
            ]))
        }
        let datos = GeneradorPDF.secciones(titulo: "Análisis de rentabilidad", subtitulo: "Comunidad: \(comunidad)", secciones)
        return DocumentoPDF(titulo: "Análisis de rentabilidad", datos: datos)
    }
}
