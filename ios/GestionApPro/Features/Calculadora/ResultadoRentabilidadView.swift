import Charts
import SwiftUI

struct ResultadoRentabilidadView: View {
    let resultado: RentabilidadResponse
    let comunidad: String

    var body: some View {
        let r = resultado
        List {
            Section {
                HStack {
                    Indicador(titulo: "Bruta", valor: Formato.porcentaje(r.rentabilidadBrutaPct))
                    Divider()
                    Indicador(titulo: "Neta", valor: Formato.porcentaje(r.rentabilidadNetaPct))
                    Divider()
                    Indicador(titulo: "Cash flow/mes", valor: Formato.euros(r.cashFlowMensual),
                              color: r.cashFlowMensual.colorSigno)
                }
                .padding(.vertical, 4)
            }

            Section {
                DestinoAlquilerChart(resultado: r)
                    .frame(height: 200)
                    .padding(.vertical, 8)
            } header: {
                Text("¿A dónde va el alquiler?")
            } footer: {
                Text("Importes mensuales. El cash flow es lo que queda tras la cuota y los gastos.")
            }

            Section("Compra") {
                FilaDato(titulo: "ITP \(comunidad) (\(Formato.porcentaje(r.itpPct)))", valor: Formato.euros(r.itpImporte))
                FilaDato(titulo: "Total compra", valor: Formato.euros(r.totalCompra))
            }
            Section("Financiación") {
                FilaDato(titulo: "Hipoteca", valor: Formato.euros(r.hipoteca))
                FilaDato(titulo: "Capital aportado", valor: Formato.euros(r.capitalAportado))
                FilaDato(titulo: "Cuota mensual", valor: Formato.euros(r.cuotaMensual))
                FilaDato(titulo: "Intereses (media/mes)", valor: Formato.euros(r.interesesMensualesPromedio))
                FilaDato(titulo: "Amortización (media/mes)", valor: Formato.euros(r.amortizacionMensualPromedio))
            }
            Section("Gastos e ingresos") {
                FilaDato(titulo: "Gastos mensuales", valor: Formato.euros(r.gastosMensuales))
                FilaDato(titulo: "Gastos anuales", valor: Formato.euros(r.gastosAnuales))
                FilaDato(titulo: "Alquiler anual", valor: Formato.euros(r.alquilerAnual))
            }
            Section("Rendimiento") {
                FilaDato(titulo: "Cash flow anual", valor: Formato.euros(r.cashFlowAnual),
                         color: r.cashFlowAnual.colorSigno)
                FilaDato(titulo: "Años para recuperar", valor: Formato.anios(r.aniosRecuperacion))
            }
            if r.plusvalia5Anios != nil || r.plusvalia10Anios != nil {
                Section("Revalorización estimada") {
                    FilaDato(titulo: "Plusvalía a 5 años", valor: Formato.euros(r.plusvalia5Anios))
                    FilaDato(titulo: "Plusvalía a 10 años", valor: Formato.euros(r.plusvalia10Anios))
                }
            }
        }
        .navigationTitle("Resultado")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Indicador: View {
    let titulo: String
    let valor: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(valor)
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(titulo)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
        func d(_ v: Decimal) -> Double { NSDecimalNumber(decimal: v).doubleValue }
        let cashFlow = d(resultado.cashFlowMensual)
        return [
            Barra(concepto: "Alquiler", importe: d(resultado.alquilerAnual) / 12, color: .accentColor),
            Barra(concepto: "Cuota", importe: d(resultado.cuotaMensual), color: .orange),
            Barra(concepto: "Gastos", importe: d(resultado.gastosMensuales), color: .purple),
            Barra(concepto: "Cash flow", importe: cashFlow, color: cashFlow < 0 ? .red : .green),
        ]
    }

    var body: some View {
        Chart(barras) { barra in
            BarMark(x: .value("Concepto", barra.concepto), y: .value("€/mes", barra.importe))
                .foregroundStyle(barra.color.gradient)
                .annotation(position: barra.importe < 0 ? .bottom : .top) {
                    Text(barra.importe.formatted(.currency(code: "EUR").precision(.fractionLength(0))
                        .locale(Formato.locale)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
        }
        .chartYAxis {
            AxisMarks { valor in
                AxisGridLine()
                AxisValueLabel {
                    if let v = valor.as(Double.self) {
                        Text(v.formatted(.number.notation(.compactName).locale(Formato.locale)))
                    }
                }
            }
        }
        .accessibilityLabel("Gráfico del destino del alquiler mensual")
    }
}
