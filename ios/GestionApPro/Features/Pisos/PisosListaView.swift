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
            .navigationTitle("Inmuebles")
            .navigationDestination(for: Piso.self) { PisoDetalleView(piso: $0).navigationTransition(.zoom(sourceID: $0.id, in: zoom)) }
            .navigationDestination(for: DestinoPiso.self) { $0.vista }
            .searchable(text: $vm.busqueda, prompt: "Buscar por dirección o ciudad")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Nuevo inmueble", systemImage: "plus") { creando = true }
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
                if vm.tiposPresentes.count > 1 {
                    SelectorTipoInmueble(tipo: $vm.tipo)
                }
                if !vm.gruposPresentes.isEmpty {
                    filtroSueltas
                }
                ResumenCarteraView(resumen: vm.resumen, grupo: vm.grupo)
                    .padding(.bottom, Tema.Espacio.xs)

                // La calculadora sin pestaña propia: aquí, en el «+» y en cada piso (Simular).
                NavigationLink(value: DestinoListaPisos.calculadora) { TarjetaAnalizarInversion() }
                    .buttonStyle(EstiloPulsable())
                    .accessibilityHint("Abre la calculadora de rentabilidad")
                    .accessibilityIdentifier("analizarInversion")

                if pisos.isEmpty {
                    if vm.estado.valor?.isEmpty == true {
                        EstadoVacio(icono: "building.2", titulo: "Sin inmuebles",
                                    mensaje: "Todavía no tienes inmuebles dados de alta.")
                    } else {
                        EstadoVacio(icono: "magnifyingglass", titulo: "Sin resultados",
                                    mensaje: "Ningún inmueble coincide con la búsqueda o el filtro.",
                                    accionTitulo: "Quitar filtros") {
                            vm.busqueda = ""
                            vm.ciudad = nil
                            vm.tipo = nil
                            vm.grupo = nil
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(vm.ciudad.map { "\(pisos.count) en \($0)" } ?? (pisos.count == 1 ? String(localized: "1 inmueble") : String(localized: "\(pisos.count) inmuebles")))
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
                        NavigationLink(value: piso) {
                            TarjetaPiso(piso: piso, situacionSuelta: vm.unidadesSueltas[piso.id]?.situacionSuelta)
                        }
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

    /// "Plazas sueltas" y "Trasteros sueltos": un toque filtra, otro lo quita.
    private var filtroSueltas: some View {
        HStack(spacing: Tema.Espacio.xs) {
            ForEach(vm.gruposPresentes) { g in
                let elegido = vm.grupo == g
                Button {
                    withAnimation(Tema.Movimiento.suave) { vm.grupo = elegido ? nil : g }
                } label: {
                    Label("\(g.nombre) · \(vm.cuantas(g))", systemImage: g.icono)
                        .font(Tema.Fuente.detalle.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(elegido ? Tema.Color.fondo : Tema.Color.texto)
                        .padding(.horizontal, Tema.Espacio.s)
                        .padding(.vertical, Tema.Espacio.xs)
                        .frame(maxWidth: .infinity)
                        .background(elegido ? Tema.Color.primario : Tema.Color.superficieElevada, in: .capsule)
                }
                .buttonStyle(EstiloPulsable())
                .accessibilityAddTraits(elegido ? .isSelected : [])
                .accessibilityIdentifier("filtroSueltas-\(g.rawValue)")
            }
        }
        .sensoryFeedback(.selection, trigger: vm.grupo)
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
    /// Con un grupo de unidades sueltas elegido, los totales son los de ese grupo.
    var grupo: GrupoSueltas? = nil

    private var textoLibres: String {
        if resumen.disponibles == 1, let grupo {
            return grupo == .trasteros ? String(localized: "1 trastero libre") : String(localized: "1 plaza libre")
        }
        return "\(resumen.disponibles) \(resumen.unidades) \(String(localized: "libres"))"
    }

    var body: some View {
        TarjetaHero(titulo: grupo.map { String(localized: "Cash flow total · \($0.nombre)") } ?? String(localized: "Cash flow previsto de la cartera"), valor: Formato.euros(resumen.cashFlowMensual),
                    tonoValor: resumen.cashFlowMensual < 0 ? .negativo : nil) {
            VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                BarraProgreso(valor: resumen.ocupacion, tono: Tono.ocupacion(resumen.ocupacion * 100))
                Text("\(Formato.porcentaje(resumen.ocupacion * 100)) de ocupación · \(textoLibres)")
                    .font(Tema.Fuente.nota)
                    .foregroundStyle(Tema.Color.textoSecundario)
            }
            if grupo != nil {
                ParDatos {
                    DatoCompacto(titulo: "Ingresos previstos al mes", valor: Formato.euros(resumen.ingresosMensuales))
                } derecha: {
                    DatoCompacto(titulo: "Rentabilidad total", valor: Formato.porcentaje(resumen.totales.rentabilidadBrutaPct))
                }
            } else {
                DatoCompacto(titulo: "Ingresos previstos al mes", valor: Formato.euros(resumen.ingresosMensuales))
            }
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
                Text("Rentabilidad, hipoteca y cash flow de un inmueble antes de comprarlo; guarda y compara.")
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
