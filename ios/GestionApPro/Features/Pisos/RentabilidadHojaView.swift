import Charts
import SwiftUI

/// Hoja de una métrica de rentabilidad: cómo se calcula con los números del piso, cobros y gastos
/// reales de 12 meses, la posición frente a los demás pisos y la calculadora con sus datos.
struct RentabilidadHojaView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let piso: Piso
    let metrica: MetricaRentabilidad
    /// Cobros de 12 meses que ya cargó el detalle del piso.
    let ingresos: [ImporteMes]

    @State private var meses: [CobrosGastosMes]?
    @State private var posicion: RankingRentabilidad.Posicion?
    @State private var rankingCargado = false
    @State private var simulando = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let m = piso.metricas {
                    VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                        TarjetaHero(titulo: metrica.titulo, valor: metrica.texto(m)) {
                            Text(metrica.explicacion).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        calculo(m)
                        SeccionTarjeta(titulo: "Cobros y gastos · 12 meses") { grafico }
                        SeccionTarjeta(titulo: "Frente a tus inmuebles") { ranking }
                        BotonPrincipal(titulo: "Simular en la calculadora", icono: "function") { simulando = true }
                        .accessibilityHint("Abre la calculadora con los datos de este inmueble para probar cambios")
                        .accessibilityIdentifier("simularCalculadora")
                    }
                    .padding(.horizontal, Tema.Espacio.m)
                    .padding(.bottom, Tema.Espacio.l)
                }
            }
            .background(Tema.Color.fondo)
            .navigationTitle(metrica.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { cerrar() }
                }
            }
            .navigationDestination(isPresented: $simulando) { CalculadoraView(entrada: .desde(piso), idPiso: piso.id, nombre: piso.direccion) }
            .task { await cargar() }
        }
    }

    private func calculo(_ m: Piso.Metricas) -> some View {
        SeccionTarjeta(titulo: "Cómo se calcula") {
            Text(metrica.formula)
                .font(Tema.Fuente.subtitulo)
                .foregroundStyle(Tema.Color.primario)
                .fixedSize(horizontal: false, vertical: true)
            let pasos = metrica.pasos(piso, m)
            ForEach(pasos, id: \.self) { p in
                Divider().overlay(Tema.Color.borde)
                HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.s) {
                    VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                        Text(p.titulo).font(p.esResultado ? Tema.Fuente.subtitulo : Tema.Fuente.cuerpo)
                        if let nota = p.nota {
                            Text(nota).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: Tema.Espacio.s)
                    Text([p.operador, p.valor].compactMap { $0 }.joined(separator: " "))
                        .font(p.esResultado ? Tema.Fuente.cifraMediana : Tema.Fuente.cifraPequena)
                        .foregroundStyle(p.esResultado ? Tema.Color.primario : Tema.Color.texto)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder private var grafico: some View {
        if let meses {
            GraficoCobrosGastos(meses: meses).frame(height: 220)
            let cobros = meses.reduce(Decimal(0)) { $0 + $1.cobros }
            let gastos = meses.reduce(Decimal(0)) { $0 + $1.gastos }
            ParDatos {
                DatoCompacto(titulo: "Cobrado", valor: Formato.euros(cobros), tono: .positivo)
            } derecha: {
                DatoCompacto(titulo: "Gastos reales", valor: Formato.euros(gastos), tono: gastos > 0 ? .negativo : nil)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity, minHeight: 160)
        }
    }

    @ViewBuilder private var ranking: some View {
        if let posicion {
            HStack(spacing: Tema.Espacio.s) {
                IconoEtiqueta(icono: posicion.puesto == 1 ? "trophy" : "list.number",
                              tono: posicion.puesto == 1 ? .positivo : .primario)
                VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                    Text(RankingRentabilidad.texto(posicion)).font(Tema.Fuente.subtitulo)
                    Text(metrica.mayorEsMejor ? "Según su \(metrica.titulo.lowercased())" : "Según los años para recuperar la inversión")
                        .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                }
            }
            .accessibilityElement(children: .combine)
        } else if rankingCargado {
            Text("No se puede comparar: faltan datos en este inmueble o en los demás.")
                .font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private func cargar() async {
        async let pisos = try? sesion.api.enviar(.pisos)
        var gastos: [Gasto] = []
        for anio in CobrosGastosMes.anios(de: ingresos) {
            if let r = try? await sesion.api.enviar(.gastos(piso: piso.id, anio: anio)) { gastos += r.lista }
        }
        withAnimation(Tema.Movimiento.suave) { meses = CobrosGastosMes.combinar(ingresos: ingresos, gastos: gastos) }
        if let lista = await pisos {
            posicion = RankingRentabilidad.posicion(de: piso.id, entre: lista, por: metrica)
        }
        rankingCargado = true
    }
}

/// Barras agrupadas de cobros y gastos por mes. Se dibujan al aparecer (sin animación con Reducir movimiento).
struct GraficoCobrosGastos: View {
    let meses: [CobrosGastosMes]
    @State private var dibujado = false
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        Chart {
            ForEach(meses) { m in
                BarMark(x: .value("Mes", m.etiqueta), y: .value("Importe", dibujado ? m.cobros.double : 0))
                    .foregroundStyle(by: .value("Tipo", "Cobros"))
                    .position(by: .value("Tipo", "Cobros"))
                    .accessibilityLabel("\(m.etiqueta.capitalized(with: Formato.localeFechas)), cobros")
                    .accessibilityValue(Formato.euros(m.cobros))
                BarMark(x: .value("Mes", m.etiqueta), y: .value("Importe", dibujado ? m.gastos.double : 0))
                    .foregroundStyle(by: .value("Tipo", "Gastos"))
                    .position(by: .value("Tipo", "Gastos"))
                    .accessibilityLabel("\(m.etiqueta.capitalized(with: Formato.localeFechas)), gastos")
                    .accessibilityValue(Formato.euros(m.gastos))
            }
        }
        .chartForegroundStyleScale(["Cobros": Tema.Color.positivo, "Gastos": Tema.Color.negativo])
        .chartLegend(position: .top, alignment: .leading)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { valor in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(Tema.Color.borde)
                AxisValueLabel {
                    if let v = valor.as(Double.self) {
                        Text(Formato.eurosRedondo(v)).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { valor in
                AxisValueLabel {
                    // Una etiqueta de cada dos, acabando en el mes actual: las 12 no caben.
                    // Hasta 6 meses caben todas; con más, una de cada dos acabando en el último.
                    if let e = valor.as(String.self), let i = meses.firstIndex(where: { $0.etiqueta == e }),
                       meses.count <= 6 || (meses.count - 1 - i) % 2 == 0 {
                        Text(e).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    }
                }
            }
        }
        .accessibilityLabel("Cobros y gastos reales por mes")
        .onAppear {
            if reducirMovimiento { dibujado = true } else { withAnimation(Tema.Movimiento.entrada.delay(0.15)) { dibujado = true } }
        }
    }
}
