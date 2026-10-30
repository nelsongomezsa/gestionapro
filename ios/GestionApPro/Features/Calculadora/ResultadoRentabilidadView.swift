import Charts
import SwiftUI

struct ResultadoRentabilidadView: View {
    let resultado: RentabilidadResponse
    let comunidad: String

    var body: some View {
        let r = resultado
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Tema.Espacio.s), GridItem(.flexible(), spacing: Tema.Espacio.s)],
                          spacing: Tema.Espacio.s) {
                    TarjetaKPI(titulo: "Rentabilidad bruta", valor: Formato.porcentaje(r.rentabilidadBrutaPct), icono: "percent")
                    TarjetaKPI(titulo: "Rentabilidad neta", valor: Formato.porcentaje(r.rentabilidadNetaPct),
                               icono: "chart.line.uptrend.xyaxis", tono: Tono.signo(r.rentabilidadNetaPct.double))
                    TarjetaKPI(titulo: "Cash flow mensual", valor: Formato.euros(r.cashFlowMensual),
                               icono: "arrow.left.arrow.right", tono: Tono.signo(r.cashFlowMensual))
                    TarjetaKPI(titulo: "Años para recuperar", valor: Formato.anios(r.aniosRecuperacion), icono: "hourglass",
                               tono: .neutro)
                }

                seccion("¿A dónde va el alquiler?") {
                    DestinoAlquilerChart(resultado: r)
                        .frame(height: 200)
                    Text("Importes mensuales. El cash flow es lo que queda tras la cuota y los gastos.")
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
    }

    private func seccion<Contenido: View>(_ titulo: String, @ViewBuilder contenido: () -> Contenido) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            Text(titulo).estiloEtiqueta().padding(.horizontal, Tema.Espacio.xxs)
            VStack(alignment: .leading, spacing: Tema.Espacio.s) { contenido() }
                .tarjeta()
        }
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
            Barra(concepto: "Gastos", importe: resultado.gastosMensuales.double, color: .gray),
            Barra(concepto: "Cash flow", importe: cashFlow, color: cashFlow < 0 ? Tema.Color.negativo : Tema.Color.positivo),
        ]
    }

    var body: some View {
        Chart(barras) { barra in
            BarMark(x: .value("Concepto", barra.concepto), y: .value("€/mes", barra.importe))
                .foregroundStyle(barra.color.gradient)
                .clipShape(.rect(cornerRadius: 6))
                .annotation(position: barra.importe < 0 ? .bottom : .top) {
                    Text(Formato.eurosRedondo(barra.importe))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Tema.Color.textoSecundario)
                }
        }
        .chartYAxis {
            AxisMarks { valor in
                AxisGridLine()
                AxisValueLabel {
                    if let v = valor.as(Double.self) { Text(Formato.eurosRedondo(v)) }
                }
            }
        }
        .accessibilityLabel("Gráfico del destino del alquiler mensual")
    }
}
