import SwiftUI

struct PisosListaView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = PisosViewModel()

    var body: some View {
        NavigationStack {
            VistaCarga(estado: vm.estado, reintentar: recargar) { _ in
                contenido
            }
            .background(Tema.Color.fondo)
            .navigationTitle("Pisos")
            .navigationDestination(for: Piso.self) { PisoDetalleView(piso: $0) }
            .navigationDestination(for: DestinoPiso.self) { $0.vista }
            .searchable(text: $vm.busqueda, prompt: "Buscar por dirección o ciudad")
            .toolbar {
                menuFiltros
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: DestinoListaPisos.mapa) { Label("Mapa", systemImage: "map") }
                        .disabled(vm.estado.valor?.isEmpty ?? true)
                }
            }
            .navigationDestination(for: DestinoListaPisos.self) { _ in MapaPisosView(pisos: vm.estado.valor ?? []) }
            .refreshable { await vm.cargar(con: sesion.api) }
            .task { await vm.cargar(con: sesion.api) }
        }
    }

    private func recargar() { Task { await vm.cargar(con: sesion.api) } }

    @ViewBuilder
    private var contenido: some View {
        let pisos = vm.pisosVisibles
        ScrollView {
            LazyVStack(spacing: Tema.Espacio.s) {
                ResumenCarteraView(resumen: vm.resumen)
                    .padding(.bottom, Tema.Espacio.xs)

                if pisos.isEmpty {
                    if vm.estado.valor?.isEmpty == true {
                        EstadoVacio(icono: "building.2", titulo: "Sin pisos",
                                    mensaje: "Todavía no tienes pisos dados de alta.")
                    } else {
                        EstadoVacio(icono: "magnifyingglass", titulo: "Sin resultados",
                                    mensaje: "Ningún piso coincide con la búsqueda o el filtro.",
                                    accionTitulo: "Quitar filtros") {
                            vm.busqueda = ""
                            vm.ciudad = nil
                        }
                    }
                } else {
                    HStack {
                        Text("\(pisos.count) \(pisos.count == 1 ? "piso" : "pisos")")
                        if let ciudad = vm.ciudad { Text("· \(ciudad)") }
                        Spacer()
                        Text("Orden: \(vm.orden.rawValue)")
                    }
                    .estiloEtiqueta()
                    .padding(.horizontal, Tema.Espacio.xxs)

                    ForEach(pisos) { piso in
                        NavigationLink(value: piso) { TarjetaPiso(piso: piso) }
                            .accessibilityIdentifier("tarjetaPiso")
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(Tema.Espacio.m)
        }
    }

    private var menuFiltros: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Ciudad", selection: $vm.ciudad) {
                    Text("Todas las ciudades").tag(String?.none)
                    ForEach(vm.ciudades, id: \.self) { Text($0).tag(String?.some($0)) }
                }
                Picker("Ordenar por", selection: $vm.orden) {
                    ForEach(PisosViewModel.Orden.allCases) { Text($0.rawValue).tag($0) }
                }
            } label: {
                Label("Filtrar y ordenar",
                      systemImage: vm.ciudad == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }
}

/// Cabecera con los totales de la cartera.
struct ResumenCarteraView: View {
    let resumen: ResumenCartera

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.m) {
            VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
                Text("Cash flow mensual de la cartera")
                    .font(Tema.Fuente.detalle)
                    .foregroundStyle(.white.opacity(0.85))
                Text(Formato.euros(resumen.cashFlowMensual))
                    .font(Tema.Fuente.cifraGrande)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            HStack {
                dato("Ingresos/mes", Formato.euros(resumen.ingresosMensuales))
                Spacer()
                dato("Ocupación", Formato.porcentaje(resumen.ocupacion * 100))
                Spacer()
                dato("Libres", "\(resumen.disponibles)")
            }
        }
        .padding(Tema.Espacio.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Color.degradadoMarca, in: .rect(cornerRadius: Tema.Radio.tarjeta))
        .accessibilityElement(children: .combine)
    }

    private func dato(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
            Text(titulo)
                .font(Tema.Fuente.nota)
                .foregroundStyle(.white.opacity(0.8))
            Text(valor)
                .font(Tema.Fuente.cifraPequena)
                .foregroundStyle(.white)
        }
    }
}

extension Piso: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum DestinoListaPisos: Hashable { case mapa }
