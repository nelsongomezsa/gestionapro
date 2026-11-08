import SwiftUI

/// Habitaciones de un piso: filtro por estado, búsqueda, cambiar estado, editar y borrar.
struct HabitacionesView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm: HabitacionesViewModel
    @State private var editando: Habitacion?
    @State private var creando = false
    @State private var paraBorrar: Habitacion?
    @State private var documento: DocumentoPDF?
    @State private var inventarios: Habitacion?

    init(piso: PisoBreve) {
        _vm = State(initialValue: HabitacionesViewModel(piso: piso))
    }

    var body: some View {
        @Bindable var vm = vm
        VistaCarga(estado: vm.estado, reintentar: { Task { await vm.cargar(con: sesion.api) } }) { _ in
            List {
                Section {
                    Picker("Estado", selection: $vm.filtro) {
                        Text(vm.piso.tipoInmueble.unidad.todas(vm.cuenta(nil))).tag(EstadoHabitacion?.none)
                        ForEach(EstadoHabitacion.allCases) { e in
                            Text("\(e.nombre(para: vm.piso.tipoInmueble.unidad)) (\(vm.cuenta(e)))").tag(EstadoHabitacion?.some(e))
                        }
                    }
                    .pickerStyle(.menu)
                }
                .filaLista()

                if vm.visibles.isEmpty {
                    EstadoVacio(icono: vm.piso.tipoInmueble.unidad.icono, titulo: vm.piso.tipoInmueble.unidad.sinUnidades,
                                mensaje: vm.cuenta(nil) == 0 ? vm.piso.tipoInmueble.unidad.inmuebleSinUnidades : String(localized: "Ninguna coincide con el filtro."))
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(vm.visibles) { h in
                            // Botón (no un gesto de toque) para que VoiceOver y los deslizamientos funcionen.
                            Button { editando = h } label: {
                                FilaHabitacion(habitacion: h).contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button("Borrar", systemImage: "trash", role: .destructive) { paraBorrar = h }
                                    Button("Editar", systemImage: "pencil") { editando = h }
                                        .tint(Tema.Color.primario)
                                }
                                .swipeActions(edge: .leading) {
                                    menuEstado(h)
                                    Button("Inventarios", systemImage: "checklist") { inventarios = h }
                                        .tint(Tema.Color.iconoMarino)
                                }
                                .contextMenu {
                                    Button("Editar", systemImage: "pencil") { editando = h }
                                    Button("Inventarios", systemImage: "checklist") { inventarios = h }
                                    Menu("Cambiar estado", systemImage: "arrow.triangle.2.circlepath") { menuEstado(h) }
                                    Button("Borrar", systemImage: "trash", role: .destructive) { paraBorrar = h }
                                }
                        }
                    } footer: {
                        Text("Desliza para editar, borrar o cambiar el estado.")
                    }
                    .filaLista()
                }
            }
            .estiloLista()
            .searchable(text: $vm.busqueda, prompt: "Número o inquilino")
        }
        .navigationTitle(vm.piso.tipoInmueble.unidad.plural)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Añadir", systemImage: "plus") { creando = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Exportar PDF", systemImage: "doc.richtext") { documento = vm.pdf() }
            }
        }
        .refreshable { await vm.cargar(con: sesion.api) }
        .task { await vm.cargar(con: sesion.api) }
        .sheet(item: $editando) { h in
            HabitacionFormView(piso: vm.piso, habitacion: h) { vm.reemplazar($0) }
        }
        .sheet(item: $inventarios) { h in
            NavigationStack {
                InventariosView(idHabitacion: h.id, titulo: "\(String(localized: "Inventarios")) · \(h.etiqueta)", unidad: h.unidad)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { inventarios = nil } } }
            }
        }
        .sheet(isPresented: $creando) {
            HabitacionFormView(piso: vm.piso, habitacion: nil) { vm.reemplazar($0) }
        }
        .confirmationDialog((paraBorrar?.unidad ?? vm.piso.tipoInmueble.unidad).borrar(paraBorrar?.numero ?? 0), isPresented: Binding(
            get: { paraBorrar != nil }, set: { if !$0 { paraBorrar = nil } }), titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if let h = paraBorrar { Task { await vm.borrar(h, con: sesion.api) } }
            }
        } message: {
            Text(vm.piso.tipoInmueble.unidad.soloBorrarSinHistorial)
        }
        .visorPDF($documento)
        .alertaError($vm.error)
    }

    @ViewBuilder
    private func menuEstado(_ h: Habitacion) -> some View {
        ForEach(EstadoHabitacion.allCases.filter { $0 != h.estado }) { e in
            Button(e.nombre, systemImage: e.icono) { Task { await vm.cambiarEstado(h, a: e, con: sesion.api) } }
                .tint(e.tono.color)
        }
    }
}

struct FilaHabitacion: View {
    let habitacion: Habitacion

    var body: some View {
        HStack(spacing: Tema.Espacio.s) {
            Text("\(habitacion.numero)")
                .font(Tema.Fuente.cifraPequena)
                .frame(width: Tema.Tamano.avatarFila, height: Tema.Tamano.avatarFila)
                .accessibilityLabel("\(habitacion.titulo)")
                .background(habitacion.estado.tono.color.opacity(0.14), in: .rect(cornerRadius: Tema.Radio.pequeno))
                .foregroundStyle(habitacion.estado.tono.color)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                if let inquilino = habitacion.inquilinoActual {
                    Text(inquilino.nombre).font(Tema.Fuente.subtitulo)
                    if let dias = habitacion.diasAlquilada {
                        Text(habitacion.unidad.alquiladaHace(dias)).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    }
                } else {
                    // El número ya está en la casilla: aquí, el estado.
                    Label(habitacion.estado.nombre(para: habitacion.unidad), systemImage: habitacion.estado.icono)
                        .font(Tema.Fuente.subtitulo)
                        .foregroundStyle(habitacion.estado.tono.color)
                }
                // Plazas y trasteros: planta, m² y coche o moto.
                if let detalle = habitacion.detalle {
                    Text(detalle).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Tema.Espacio.linea) {
                Text(Formato.euros(habitacion.precio)).font(Tema.Fuente.cifraPequena)
                Text("al mes").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
        }
        .padding(.vertical, Tema.Espacio.linea)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para editar; desliza para más acciones")
    }
}
