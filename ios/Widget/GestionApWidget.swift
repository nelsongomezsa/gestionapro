import SwiftUI
import WidgetKit

struct Entrada: TimelineEntry {
    let date: Date
    let resumen: ResumenWidget?
}

struct Proveedor: TimelineProvider {
    func placeholder(in context: Context) -> Entrada {
        Entrada(date: .now, resumen: ResumenWidget(mes: "octubre", cobrado: 5730, esperado: 11420, pendientes: 10,
                                                  incidenciasAbiertas: 12, actualizado: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (Entrada) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : Entrada(date: .now, resumen: ResumenWidget.leer()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entrada>) -> Void) {
        // La app lo recarga al abrir Inicio; además se revisa cada hora por si cambió de mes.
        completion(Timeline(entries: [Entrada(date: .now, resumen: ResumenWidget.leer())],
                            policy: .after(.now.addingTimeInterval(3600))))
    }
}

private let marino = Color(red: 15 / 255, green: 27 / 255, blue: 51 / 255)
private let azul = Color(red: 92 / 255, green: 151 / 255, blue: 255 / 255)
private let verde = Color(red: 61 / 255, green: 214 / 255, blue: 140 / 255)
private let ambar = Color(red: 1, green: 179 / 255, blue: 64 / 255)

private func euros(_ v: Decimal) -> String {
    v.formatted(.currency(code: "EUR").precision(.fractionLength(0)).locale(Locale(identifier: "es_ES")))
}

struct VistaWidget: View {
    @Environment(\.widgetFamily) private var familia
    let entrada: Entrada

    var body: some View {
        if let r = entrada.resumen {
            switch familia {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cobrado en \(r.mes)").font(.caption2)
                    Text(euros(r.cobrado)).font(.headline).monospacedDigit()
                    Gauge(value: r.progreso) { EmptyView() }.gaugeStyle(.accessoryLinear)
                }
            default:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cobrado en \(r.mes)").font(.caption).foregroundStyle(.white.opacity(0.75))
                    Text(euros(r.cobrado)).font(.title2.bold()).monospacedDigit().foregroundStyle(.white)
                        .minimumScaleFactor(0.7).lineLimit(1)
                    ProgressView(value: r.progreso).tint(verde)
                    Text("de \(euros(r.esperado)) esperados").font(.caption2).foregroundStyle(.white.opacity(0.75))
                    if familia == .systemMedium {
                        HStack(spacing: 16) {
                            Label("\(r.pendientes) sin pagar", systemImage: "eurosign.circle").foregroundStyle(ambar)
                            Label("\(r.incidenciasAbiertas) incidencias", systemImage: "wrench.and.screwdriver").foregroundStyle(azul)
                        }
                        .font(.caption)
                    } else {
                        Text("\(r.pendientes) sin pagar").font(.caption).foregroundStyle(ambar)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "building.2").foregroundStyle(azul)
                Text("Abre GestionAp para ver tus cobros").font(.caption).foregroundStyle(.white)
            }
        }
    }
}

@main
struct GestionApWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CobrosDelMes", provider: Proveedor()) { entrada in
            VistaWidget(entrada: entrada)
                .containerBackground(marino, for: .widget)
                .widgetURL(URL(string: "gestionap://cobros"))
        }
        .configurationDisplayName("Cobros del mes")
        .description("Lo cobrado este mes, lo esperado y quién no ha pagado.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
