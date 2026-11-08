import SwiftUI

/// Habitaciones libres de todos los pisos (tarjeta de Inicio): primero las que llevan más tiempo
/// sin alquilar. Un interruptor añade las que están en mantenimiento.
struct HabitacionesLibresView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<[Habitacion]> = .cargando
    @State private var incluirMantenimiento = false
    /// "Habitaciones libres" o, con garajes o trasteros, "Unidades libres".
    @State private var titulo = String(localized: "Habitaciones libres")
    /// Abre una pantalla en la pila de Inicio.
    let abrir: (DestinoInicio) -> Void

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { todas in
            let visibles = ResumenesInicio.libres(todas, incluirMantenimiento: incluirMantenimiento)
            // Con garajes o trasteros en la cartera, los textos dicen "unidades".
            let otros = todas.contains { $0.unidad != .habitacion }
            List {
                Section {
                    Toggle(isOn: $incluirMantenimiento.animation(Tema.Movimiento.suave)) {
                        Label("Incluir en mantenimiento", systemImage: EstadoHabitacion.mantenimiento.icono)
                    }
                    .tint(Tema.Color.primario)
                    .sensoryFeedback(.selection, trigger: incluirMantenimiento)
                }
                .filaLista()

                if visibles.isEmpty {
                    EstadoVacio(icono: "checkmark.seal", titulo: "Todo alquilado",
                                mensaje: otros
                                    ? (incluirMantenimiento ? String(localized: "No hay unidades libres ni en mantenimiento.")
                                                            : String(localized: "No hay unidades libres."))
                                    : (incluirMantenimiento ? String(localized: "No hay habitaciones libres ni en mantenimiento.")
                                                            : String(localized: "No hay habitaciones libres.")))
                        .listRowBackground(Color.clear)
                } else {
                    Section(otros ? (visibles.count == 1 ? String(localized: "1 unidad") : String(localized: "\(visibles.count) unidades"))
                                  : TipoUnidad.habitacion.cantidad(visibles.count)) {
                        ForEach(visibles) { h in
                            TarjetaTocable(pista: String(localized: "Abre la ficha para crear un contrato"), mostrarChevron: false,
                                           accion: { abrir(.fichaHabitacion(h)) }) { FilaHabitacionLibre(habitacion: h) }
                                .accessibilityIdentifier("filaHabitacionLibre")
                        }
                    }
                    .filaLista()
                }
            }
            .estiloLista()
        }
        .navigationTitle(titulo)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .datosCambiados)) { _ in Task { await cargar() } }
        .refreshable { await cargar() }
        .task { await cargar() }
    }

    private func cargar() async {
        do {
            let todas: [Habitacion] = try await sesion.api.enviar(.habitaciones())
            titulo = todas.contains { $0.unidad != .habitacion } ? String(localized: "Unidades libres") : String(localized: "Habitaciones libres")
            estado = .cargado(todas)
        }
        catch .noAutorizado {}
        catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) }
        }
    }
}

private struct FilaHabitacionLibre: View {
    let habitacion: Habitacion

    var body: some View {
        let h = habitacion
        HStack(spacing: Tema.Espacio.s) {
            Text(h.unidad == .habitacion ? "\(h.numero)" : "\(h.etiqueta)")
                .font(Tema.Fuente.cifraPequena)
                .minimumScaleFactor(0.5).lineLimit(2).multilineTextAlignment(.center)
                .frame(width: Tema.Tamano.avatarFila, height: Tema.Tamano.avatarFila)
                .background(h.estado.tono.color.opacity(0.14), in: .rect(cornerRadius: Tema.Radio.pequeno))
                .foregroundStyle(h.estado.tono.color)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(h.piso.direccion).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                    .fixedSize(horizontal: false, vertical: true)
                Text(ResumenesInicio.textoLibre(h)).font(Tema.Fuente.nota)
                    .foregroundStyle(h.estado == .mantenimiento ? Tema.Color.aviso : Tema.Color.textoSecundario)
            }
            Spacer(minLength: Tema.Espacio.xs)
            VStack(alignment: .trailing, spacing: Tema.Espacio.linea) {
                Text(Formato.euros(h.precio)).font(Tema.Fuente.cifraPequena)
                Text("al mes").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
            ChevronTocable()
        }
        .padding(.vertical, Tema.Espacio.linea)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(h.titulo), \(h.piso.direccion). \(Formato.euros(h.precio)) al mes. \(ResumenesInicio.textoLibre(h))")
    }
}

/// Ficha de una habitación sin alquilar, con acceso directo a "Nuevo contrato".
struct HabitacionFichaView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var habitacion: Habitacion
    /// Abre el contrato recién creado (lo decide quien tiene la pila de navegación).
    let alCrearContrato: (Contrato) -> Void
    @State private var creando = false
    @State private var inventarios = false
    @State private var cambiandoEstado = false
    @State private var error: String?

    init(habitacion: Habitacion, alCrearContrato: @escaping (Contrato) -> Void) {
        _habitacion = State(initialValue: habitacion)
        self.alCrearContrato = alCrearContrato
    }

    var body: some View {
        let h = habitacion
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                TarjetaHero(titulo: "\(h.titulo)", valor: Formato.euros(h.precio),
                            accesorio: AnyView(InsigniaEstado(texto: h.estado.nombre(para: h.unidad), tono: h.estado.tono, icono: h.estado.icono))) {
                    Text(ResumenesInicio.textoLibre(h)).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                    switch h.estado {
                    case .disponible:
                        BotonPrincipal(titulo: "Nuevo contrato", icono: "doc.badge.plus") { creando = true }
                            .accessibilityIdentifier("nuevoContratoHabitacion")
                    case .mantenimiento:
                        Text(h.unidad == .trastero ? String(localized: "Para alquilarlo, márcalo antes como disponible.")
                                                   : String(localized: "Para alquilarla, márcala antes como disponible."))
                            .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                        BotonPrincipal(titulo: "Marcar como disponible", icono: EstadoHabitacion.disponible.icono,
                                       cargando: cambiandoEstado) { Task { await marcarDisponible() } }
                    case .alquilada:
                        EmptyView()
                    }
                }

                SeccionTarjeta(titulo: "Inmueble") {
                    NavigationLink(value: DestinoInicio.piso(h.piso.id)) {
                        FilaMetrica(titulo: h.piso.direccion, valor: "", nota: h.piso.ciudad, icono: "building.2")
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Abre el detalle del inmueble")
                    .accessibilityIdentifier("enlacePisoFicha")
                    Divider().overlay(Tema.Color.borde)
                    Button { inventarios = true } label: {
                        FilaMetrica(titulo: "Inventarios", valor: "", icono: "checklist")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Tema.Espacio.m)
            .padding(.bottom, Tema.Espacio.l)
        }
        .background(Tema.Color.fondo)
        .navigationTitle("\(h.titulo)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $creando) {
            NuevoContratoView(habitacionInicial: h) { c in
                NotificationCenter.default.post(name: .datosCambiados, object: nil)
                alCrearContrato(c)
            }
        }
        .sheet(isPresented: $inventarios) {
            NavigationStack {
                InventariosView(idHabitacion: h.id, titulo: "\(String(localized: "Inventarios")) · \(h.etiqueta)", unidad: h.unidad)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { inventarios = false } } }
            }
        }
        .alertaError($error)
    }

    private func marcarDisponible() async {
        cambiandoEstado = true
        defer { cambiandoEstado = false }
        do {
            habitacion = try await sesion.api.enviar(.cambiarEstado(habitacion: habitacion.id, a: .disponible))
            Haptica.exito()
            NotificationCenter.default.post(name: .datosCambiados, object: nil)
        } catch .noAutorizado {
        } catch {
            Haptica.error()
            self.error = error.localizedDescription
        }
    }
}
