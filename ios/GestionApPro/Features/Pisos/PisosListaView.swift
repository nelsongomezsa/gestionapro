import SwiftUI

struct PisosListaView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = PisosViewModel()

    var body: some View {
        NavigationStack {
            contenido
                .navigationTitle("Mis Pisos")
                .navigationDestination(for: Piso.self) { PisoDetalleView(piso: $0) }
                .refreshable { await vm.cargar(con: sesion.api) }
                .task { await vm.cargar(con: sesion.api) }
        }
    }

    @ViewBuilder
    private var contenido: some View {
        switch vm.estado {
        case .cargando:
            ProgressView("Cargando pisos…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .vacio:
            ScrollView {
                ContentUnavailableView("Sin pisos", systemImage: "building.2",
                                       description: Text("Todavía no tienes pisos dados de alta."))
            }
        case let .error(mensaje):
            ScrollView {
                ContentUnavailableView {
                    Label("No se pudieron cargar los pisos", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(mensaje)
                } actions: {
                    Button("Reintentar") { Task { await vm.cargar(con: sesion.api) } }
                        .buttonStyle(.borderedProminent)
                }
            }
        case let .cargado(pisos):
            List(pisos) { piso in
                NavigationLink(value: piso) { PisoFilaView(piso: piso) }
            }
        }
    }
}

struct PisoFilaView: View {
    let piso: Piso

    var body: some View {
        HStack(spacing: 12) {
            SemaforoView(calificacion: piso.metricas?.calificacion)
            VStack(alignment: .leading, spacing: 2) {
                Text(piso.direccion)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(piso.ciudad.nombre) · \(piso.ocupacion.alquiladas)/\(piso.ocupacion.total) hab. alquiladas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if let metricas = piso.metricas {
                    Text(Formato.euros(metricas.cashFlowMensual))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(metricas.cashFlowMensual.colorSigno)
                    Text("cash flow/mes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Sin datos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

extension Piso: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
