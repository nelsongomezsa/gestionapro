import SwiftUI

struct InquilinosView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = InquilinosViewModel()
    @State private var creando = false
    @State private var editando: Inquilino?
    @State private var paraBorrar: Inquilino?
    @State private var documento: DocumentoPDF?

    var body: some View {
        @Bindable var vm = vm
        VistaCarga(estado: vm.estado, reintentar: { Task { await vm.cargar(con: sesion.api) } }) { _ in
            List {
                Toggle("Solo con contrato activo", isOn: $vm.soloConContrato)
                if vm.visibles.isEmpty {
                    EstadoVacio(icono: "person.2", titulo: vm.busqueda.isEmpty && !vm.soloConContrato ? "Sin inquilinos" : "Sin resultados",
                                mensaje: vm.busqueda.isEmpty && !vm.soloConContrato ? "Da de alta tu primer inquilino con +." : "Prueba con otro nombre, DNI o teléfono.")
                        .listRowBackground(Color.clear)
                } else {
                    Section("\(vm.visibles.count) inquilinos") {
                        ForEach(vm.visibles) { i in
                            NavigationLink(value: i) { FilaInquilino(inquilino: i) }
                                .accessibilityIdentifier("filaInquilino")
                                .swipeActions(edge: .trailing) {
                                    Button("Borrar", systemImage: "trash", role: .destructive) { paraBorrar = i }
                                    Button("Editar", systemImage: "pencil") { editando = i }.tint(Tema.Color.primario)
                                }
                        }
                    }
                }
            }
            .searchable(text: $vm.busqueda, prompt: "Nombre, DNI, teléfono o email")
        }
        .navigationTitle("Inquilinos")
        .navigationDestination(for: Inquilino.self) { InquilinoFichaView(id: $0.id, alCambiar: { Task { await vm.cargar(con: sesion.api) } }) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Nuevo inquilino", systemImage: "plus") { creando = true } }
            ToolbarItem(placement: .secondaryAction) { Button("Exportar PDF", systemImage: "doc.richtext") { documento = vm.pdf() } }
        }
        .refreshable { await vm.cargar(con: sesion.api) }
        .task { await vm.cargar(con: sesion.api) }
        .sheet(isPresented: $creando) { InquilinoFormView(inquilino: nil) { _ in Task { await vm.cargar(con: sesion.api) } } }
        .sheet(item: $editando) { i in InquilinoFormView(inquilino: i) { _ in Task { await vm.cargar(con: sesion.api) } } }
        .confirmationDialog("¿Borrar a \(paraBorrar?.nombreCompleto ?? "")?", isPresented: Binding(
            get: { paraBorrar != nil }, set: { if !$0 { paraBorrar = nil } }), titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { if let i = paraBorrar { Task { await vm.borrar(i, con: sesion.api) } } }
        } message: {
            Text("Solo se pueden borrar inquilinos sin contratos ni incidencias.")
        }
        .visorPDF($documento)
        .alertaError($vm.error)
    }
}

struct FilaInquilino: View {
    let inquilino: Inquilino

    var body: some View {
        HStack(spacing: Tema.Espacio.s) {
            AvatarIniciales(nombre: inquilino.nombreCompleto, tamano: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Tema.Espacio.xxs) {
                    Text(inquilino.nombreCompleto).font(Tema.Fuente.subtitulo)
                    if inquilino.tieneCuentaApp {
                        Image(systemName: "iphone").font(.caption).foregroundStyle(Tema.Color.primario)
                            .accessibilityLabel("Usa la app")
                    }
                }
                if let c = inquilino.contratoActivo {
                    Text("Hab. \(c.numeroHabitacion) · \(c.piso.direccion)")
                        .font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario).lineLimit(1)
                } else {
                    Text("Sin contrato activo").font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                }
            }
            Spacer()
            if let c = inquilino.contratoActivo, c.vencimiento != .normal {
                InsigniaEstado(texto: c.vencimiento == .critico ? "≤ 7 días" : "≤ 30 días", tono: c.vencimiento.tono,
                               icono: "calendar.badge.exclamationmark")
            }
        }
        .accessibilityElement(children: .combine)
    }
}
