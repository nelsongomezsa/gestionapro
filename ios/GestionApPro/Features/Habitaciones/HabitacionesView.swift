import SwiftUI

/// Habitaciones de un piso: filtro por estado, búsqueda, cambiar estado, editar y borrar.
struct HabitacionesView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm: HabitacionesViewModel
    @State private var editando: Habitacion?
    @State private var creando = false
    @State private var paraBorrar: Habitacion?
    @State private var documento: DocumentoPDF?

    init(piso: PisoBreve) {
        _vm = State(initialValue: HabitacionesViewModel(piso: piso))
    }

    var body: some View {
        @Bindable var vm = vm
        VistaCarga(estado: vm.estado, reintentar: { Task { await vm.cargar(con: sesion.api) } }) { _ in
            List {
                Section {
                    Picker("Estado", selection: $vm.filtro) {
                        Text("Todas (\(vm.cuenta(nil)))").tag(EstadoHabitacion?.none)
                        ForEach(EstadoHabitacion.allCases) { e in
                            Text("\(e.nombre) (\(vm.cuenta(e)))").tag(EstadoHabitacion?.some(e))
                        }
                    }
                    .pickerStyle(.menu)
                }

                if vm.visibles.isEmpty {
                    EstadoVacio(icono: "bed.double", titulo: "Sin habitaciones",
                                mensaje: vm.cuenta(nil) == 0 ? "Este piso aún no tiene habitaciones." : "Ninguna coincide con el filtro.")
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(vm.visibles) { h in
                            FilaHabitacion(habitacion: h)
                                .contentShape(.rect)
                                .onTapGesture { editando = h }
                                .swipeActions(edge: .trailing) {
                                    Button("Borrar", systemImage: "trash", role: .destructive) { paraBorrar = h }
                                    Button("Editar", systemImage: "pencil") { editando = h }
                                        .tint(Tema.Color.primario)
                                }
                                .swipeActions(edge: .leading) { menuEstado(h) }
                                .contextMenu {
                                    Button("Editar", systemImage: "pencil") { editando = h }
                                    Menu("Cambiar estado", systemImage: "arrow.triangle.2.circlepath") { menuEstado(h) }
                                    Button("Borrar", systemImage: "trash", role: .destructive) { paraBorrar = h }
                                }
                        }
                    } footer: {
                        Text("Desliza para editar, borrar o cambiar el estado.")
                    }
                }
            }
            .searchable(text: $vm.busqueda, prompt: "Número o inquilino")
        }
        .navigationTitle("Habitaciones")
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
        .sheet(isPresented: $creando) {
            HabitacionFormView(piso: vm.piso, habitacion: nil) { vm.reemplazar($0) }
        }
        .confirmationDialog("¿Borrar la habitación \(paraBorrar?.numero ?? 0)?", isPresented: Binding(
            get: { paraBorrar != nil }, set: { if !$0 { paraBorrar = nil } }), titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if let h = paraBorrar { Task { await vm.borrar(h, con: sesion.api) } }
            }
        } message: {
            Text("Solo se pueden borrar habitaciones sin contratos ni incidencias.")
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
                .frame(width: 40, height: 40)
                .background(habitacion.estado.tono.color.opacity(0.14), in: .rect(cornerRadius: Tema.Radio.pequeno))
                .foregroundStyle(habitacion.estado.tono.color)
            VStack(alignment: .leading, spacing: 2) {
                if let inquilino = habitacion.inquilinoActual {
                    Text(inquilino.nombre).font(Tema.Fuente.subtitulo)
                    if let dias = habitacion.diasAlquilada {
                        Text("Alquilada hace \(dias) días").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    }
                } else {
                    Text("Habitación \(habitacion.numero)").font(Tema.Fuente.subtitulo)
                    InsigniaEstado(texto: habitacion.estado.nombre, tono: habitacion.estado.tono, icono: habitacion.estado.icono)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formato.euros(habitacion.precio)).font(Tema.Fuente.cifraPequena)
                Text("al mes").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toca para editar; desliza para más acciones")
    }
}
