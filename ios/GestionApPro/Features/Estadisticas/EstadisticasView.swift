import Charts
import SwiftUI

/// Estadísticas (EstadisticasController del escritorio), filtradas por propietario.
struct EstadisticasView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<Estadisticas> = .cargando

    private let columnas = [GridItem(.flexible(), spacing: Tema.Espacio.s), GridItem(.flexible(), spacing: Tema.Espacio.s)]

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { e in
            ScrollView {
                VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                    LazyVGrid(columns: columnas, spacing: Tema.Espacio.s) {
                        TarjetaKPI(titulo: "Ingresos \(e.anioActual)", valor: Formato.euros(e.ingresosAnioActual), icono: "eurosign",
                                   tendencia: e.variacionAnualPct)
                        TarjetaKPI(titulo: "Ingresos \(e.anioActual - 1)", valor: Formato.euros(e.ingresosAnioAnterior),
                                   icono: "clock.arrow.circlepath", tono: .neutro)
                        TarjetaKPI(titulo: "Variación anual", valor: e.variacionAnualPct.map { Formato.porcentaje($0) } ?? "—",
                                   icono: "chart.line.uptrend.xyaxis", tono: Tono.signo(e.variacionAnualPct))
                        TarjetaKPI(titulo: "Tasa de ocupación", valor: Formato.porcentaje(e.ocupacion.porcentaje),
                                   icono: "chart.pie", tono: e.ocupacion.tono, detalle: e.ocupacion.salud)
                    }

                    seccion("Evolución de ingresos (12 meses)") {
                        Chart(e.ingresos12Meses, id: \.mes) { m in
                            AreaMark(x: .value("Mes", m.etiqueta), y: .value("Cobrado", m.importe.double))
                                .foregroundStyle(Tema.Color.primario.opacity(0.15).gradient)
                                .interpolationMethod(.monotone)
                            LineMark(x: .value("Mes", m.etiqueta), y: .value("Cobrado", m.importe.double))
                                .foregroundStyle(Tema.Color.primario)
                                .interpolationMethod(.monotone)
                                .symbol(.circle)
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisGridLine()
                                AxisValueLabel { if let d = v.as(Double.self) { Text(Formato.eurosRedondo(d)) } }
                            }
                        }
                        .frame(height: 200)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Ingresos de los últimos 12 meses")
                        .accessibilityValue(e.ingresos12Meses.map { "\($0.etiqueta): \(Formato.euros($0.importe))" }.joined(separator: ", "))
                    }

                    seccion("Habitaciones por estado") {
                        let porciones: [(String, Int, Color)] = [
                            ("Alquiladas", e.ocupacion.alquiladas, Tema.Color.positivo),
                            ("Disponibles", e.ocupacion.disponibles, Tema.Color.primario),
                            ("Mantenimiento", e.ocupacion.mantenimiento, Tema.Color.aviso),
                        ]
                        HStack(spacing: Tema.Espacio.l) {
                            Chart(porciones, id: \.0) { p in
                                SectorMark(angle: .value("Habitaciones", p.1), innerRadius: .ratio(0.6), angularInset: 1.5)
                                    .foregroundStyle(p.2)
                                    .cornerRadius(4)
                            }
                            .frame(width: 140, height: 140)
                            .overlay {
                                VStack(spacing: 0) {
                                    Text(Formato.porcentaje(e.ocupacion.porcentaje)).font(Tema.Fuente.cifraPequena)
                                    Text("ocupación").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                                }
                            }
                            VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                                ForEach(porciones, id: \.0) { p in
                                    HStack {
                                        Circle().fill(p.2).frame(width: 10, height: 10)
                                        Text(p.0)
                                        Spacer()
                                        Text("\(p.1)").font(Tema.Fuente.cifraPequena)
                                    }
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }

                    seccion("Incidencias por mes (6 meses)") {
                        Chart(e.incidencias6Meses, id: \.mes) { m in
                            BarMark(x: .value("Mes", m.etiqueta), y: .value("Incidencias", m.cantidad))
                                .foregroundStyle(Tema.Color.aviso.gradient)
                                .clipShape(.rect(cornerRadius: 6))
                                .annotation(position: .top) {
                                    if m.cantidad > 0 { Text("\(m.cantidad)").font(.caption2).foregroundStyle(Tema.Color.textoSecundario) }
                                }
                        }
                        .chartYAxis(.hidden)
                        .frame(height: 160)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Incidencias por mes")
                        .accessibilityValue(e.incidencias6Meses.map { "\($0.etiqueta): \($0.cantidad)" }.joined(separator: ", "))
                    }
                }
                .padding(Tema.Espacio.m)
            }
            .background(Tema.Color.fondo)
        }
        .navigationTitle("Estadísticas")
        .refreshable { await cargar() }
        .task { await cargar() }
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(.estadisticas)) }
        catch .noAutorizado {}
        catch { estado = .error(error.localizedDescription) }
    }

    private func seccion<Contenido: View>(_ titulo: String, @ViewBuilder contenido: () -> Contenido) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            Text(titulo).estiloEtiqueta().padding(.horizontal, Tema.Espacio.xxs)
            VStack(alignment: .leading, spacing: Tema.Espacio.s) { contenido() }.tarjeta()
        }
    }
}
