import SwiftUI

struct PisosListaView: View {
    /// Tarjeta → detalle con zoom (el sistema lo simplifica con Reducir movimiento).
    @Namespace private var zoom
    @Environment(SesionStore.self) private var sesion
    @State private var vm = PisosViewModel()
    @State private var ruta = NavigationPath()
    @State private var creando = false
    @Environment(IrAPiso.self) private var irAPiso: IrAPiso?

    var body: some View {
        NavigationStack(path: $ruta) {
            VistaCarga(estado: vm.estado, reintentar: recargar) { _ in
                contenido
            }
            .background(Tema.Color.fondo)
            .navigationTitle("Pisos")
            .navigationDestination(for: Piso.self) { PisoDetalleView(piso: $0).navigationTransition(.zoom(sourceID: $0.id, in: zoom)) }
            .navigationDestination(for: DestinoPiso.self) { $0.vista }
            .searchable(text: $vm.busqueda, prompt: "Buscar por dirección o ciudad")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Nuevo piso", systemImage: "plus") { creando = true }
                        .accessibilityIdentifier("nuevoPiso")
                }
                menuFiltros
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: DestinoListaPisos.mapa) { Label("Mapa", systemImage: "map") }
                        .disabled(vm.estado.valor?.isEmpty ?? true)
                }
            }
            .navigationDestination(for: DestinoListaPisos.self) { destino in
                switch destino {
                case .mapa: MapaPisosView(pisos: vm.estado.valor ?? [])
                case .calculadora: CalculadoraView()
                }
            }
            .refreshable { await vm.cargar(con: sesion.api) }
            .onReceive(NotificationCenter.default.publisher(for: .datosCambiados)) { _ in recargar() }
            .sheet(isPresented: $creando) { NuevoPisoView { abrir($0) } }
            // Piso creado desde el «+» general: se abre aquí.
            .onChange(of: irAPiso?.piso, initial: true) { _, nuevo in
                guard let nuevo else { return }
                irAPiso?.piso = nil
                abrir(nuevo)
            }
            .task { await vm.cargar(con: sesion.api) }
        }
    }

    private func recargar() { Task { await vm.cargar(con: sesion.api) } }

    /// Abre el piso recién creado (la lista ya se recarga con .datosCambiados).
    private func abrir(_ piso: Piso) {
        ruta = NavigationPath()
        ruta.append(piso)
    }

    @ViewBuilder
    private var contenido: some View {
        let pisos = vm.pisosVisibles
        ScrollView {
            LazyVStack(spacing: Tema.Espacio.s) {
                ResumenCarteraView(resumen: vm.resumen)
                    .padding(.bottom, Tema.Espacio.xs)

                // La calculadora sin pestaña propia: aquí, en el «+» y en cada piso (Simular).
                NavigationLink(value: DestinoListaPisos.calculadora) { TarjetaAnalizarInversion() }
                    .buttonStyle(EstiloPulsable())
                    .accessibilityHint("Abre la calculadora de rentabilidad")
                    .accessibilityIdentifier("analizarInversion")

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
                    HStack(alignment: .firstTextBaseline) {
                        Text(vm.ciudad.map { "\(pisos.count) en \($0)" } ?? "\(pisos.count) \(pisos.count == 1 ? "piso" : "pisos")")
                            .font(Tema.Fuente.tituloSeccion)
                            .foregroundStyle(Tema.Color.texto)
                        Spacer()
                        Text("Por \(vm.orden.rawValue.lowercased())")
                            .font(Tema.Fuente.nota)
                            .foregroundStyle(Tema.Color.textoSecundario)
                            .accessibilityLabel("Ordenados por \(vm.orden.rawValue)")
                    }
                    .padding(.horizontal, Tema.Espacio.xxs)
                    .padding(.top, Tema.Espacio.xs)

                    ForEach(pisos) { piso in
                        NavigationLink(value: piso) { TarjetaPiso(piso: piso) }
                            .matchedTransitionSource(id: piso.id, in: zoom)
                            .contextMenu {
                                if let url = URL(string: "maps://?q=" + "\(piso.direccion), \(piso.ciudad.nombre)"
                                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
                                    Link(destination: url) { Label("Abrir en Mapas", systemImage: "map") }
                                }
                                Button("Copiar dirección", systemImage: "doc.on.doc") {
                                    UIPasteboard.general.string = "\(piso.direccion), \(piso.ciudad.nombre)"
                                }
                            }
                            .accessibilityIdentifier("tarjetaPiso")
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Tema.Espacio.m)
            .padding(.bottom, Tema.Espacio.l)
        }
        .background(Tema.Color.fondo)
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

/// Cabecera con los totales previstos de la cartera (contratos activos y datos financieros).
struct ResumenCarteraView: View {
    let resumen: ResumenCartera

    var body: some View {
        TarjetaHero(titulo: "Cash flow previsto de la cartera", valor: Formato.euros(resumen.cashFlowMensual),
                    tonoValor: resumen.cashFlowMensual < 0 ? .negativo : nil) {
            VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                BarraProgreso(valor: resumen.ocupacion, tono: Tono.ocupacion(resumen.ocupacion * 100))
                Text("\(Formato.porcentaje(resumen.ocupacion * 100)) de ocupación · \(resumen.disponibles) habitaciones libres")
                    .font(Tema.Fuente.nota)
                    .foregroundStyle(Tema.Color.textoSecundario)
            }
            DatoCompacto(titulo: "Ingresos previstos al mes", valor: Formato.euros(resumen.ingresosMensuales))
        }
    }
}

extension Piso: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum DestinoListaPisos: Hashable { case mapa, calculadora }

/// Acceso a la calculadora desde Pisos: estudiar un piso antes de comprarlo.
private struct TarjetaAnalizarInversion: View {
    var body: some View {
        HStack(spacing: Tema.Espacio.s) {
            IconoEtiqueta(icono: "function", tono: .primario)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text("Analizar una inversión").font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                Text("Rentabilidad, hipoteca y cash flow de un piso antes de comprarlo; guarda y compara.")
                    .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: Tema.Espacio.xs)
            ChevronTocable()
        }
        .tarjeta()
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
