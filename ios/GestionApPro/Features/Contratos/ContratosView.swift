import SwiftUI

struct ContratosView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = ContratosViewModel()
    @State private var creando = false
    @State private var paraFinalizar: Contrato?
    @State private var documento: DocumentoPDF?

    var body: some View {
        @Bindable var vm = vm
        VistaCarga(estado: vm.estado, reintentar: { Task { await vm.cargar(con: sesion.api) } }) { _ in
            List {
                SelectorSegmentado(opciones: FiltroContratos.allCases.map { ($0, $0.nombre) }, seleccion: $vm.filtro)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if vm.visibles.isEmpty {
                    EstadoVacio(icono: "doc.text", titulo: "Sin contratos",
                                mensaje: vm.busqueda.isEmpty ? "No hay contratos «\(vm.filtro.nombre.lowercased())»." : "Ningún contrato coincide con la búsqueda.")
                        .listRowBackground(Color.clear)
                } else {
                    Section("\(vm.visibles.count) contratos") {
                        ForEach(vm.visibles) { c in
                            NavigationLink(value: c) { FilaContratoCompleto(contrato: c) }
                                .accessibilityIdentifier("filaContrato")
                                .swipeActions(edge: .trailing) {
                                    if c.activo {
                                        Button("Finalizar", systemImage: "flag.checkered") { paraFinalizar = c }
                                            .tint(Tema.Color.negativo)
                                    }
                                }
                        }
                    }
                    .filaLista()
                }
            }
            .estiloLista()
            .searchable(text: $vm.busqueda, prompt: "Inquilino o dirección")
        }
        .navigationTitle("Contratos")
        .navigationDestination(for: Contrato.self) { ContratoDetalleView(id: $0.id) { Task { await vm.cargar(con: sesion.api) } } }
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Nuevo contrato", systemImage: "plus") { creando = true } }
            ToolbarItem(placement: .secondaryAction) { Button("Exportar PDF", systemImage: "doc.richtext") { documento = vm.pdf() } }
        }
        .onChange(of: vm.filtro) { Task { await vm.cargar(con: sesion.api) } }
        .refreshable { await vm.cargar(con: sesion.api) }
        .task { await vm.cargar(con: sesion.api) }
        .sheet(isPresented: $creando) { NuevoContratoView { _ in Task { await vm.cargar(con: sesion.api) } } }
        .confirmationDialog("¿Finalizar el contrato de \(paraFinalizar?.inquilino.nombre ?? "")?", isPresented: Binding(
            get: { paraFinalizar != nil }, set: { if !$0 { paraFinalizar = nil } }), titleVisibility: .visible) {
            Button("Finalizar hoy", role: .destructive) { if let c = paraFinalizar { Task { await vm.finalizar(c, con: sesion.api) } } }
        } message: {
            Text("La fecha de fin pasa a ser hoy y la habitación queda disponible.")
        }
        .visorPDF($documento)
        .alertaError($vm.error)
    }
}

struct FilaContratoCompleto: View {
    let contrato: Contrato
    /// false dentro del detalle de un piso: la dirección ya está en la cabecera.
    var mostrarPiso = true

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(contrato.inquilino.nombre).font(Tema.Fuente.subtitulo)
                Spacer()
                Text(Formato.euros(contrato.precioMensual)).font(Tema.Fuente.cifraPequena)
            }
            Text(mostrarPiso ? "Hab. \(contrato.habitacion.numero) · \(contrato.piso.direccion)" : "Habitación \(contrato.habitacion.numero)")
                .font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
            HStack {
                Text(FormatoFecha.rango(contrato.fechaInicio, contrato.fechaFin))
                    .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                Spacer()
                // "Vigente" no se muestra: es lo normal y llenaría la lista de insignias iguales.
                if !contrato.activo || contrato.vencimiento != .normal {
                InsigniaEstado(texto: contrato.activo ? textoVencimiento : "Finalizado",
                               tono: contrato.activo ? contrato.vencimiento.tono : .neutro,
                               icono: contrato.activo && contrato.vencimiento != .normal ? "calendar.badge.exclamationmark" : nil)
                }
            }
        }
        .padding(.vertical, Tema.Espacio.linea)
        .accessibilityElement(children: .combine)
    }

    private var textoVencimiento: String {
        switch contrato.vencimiento {
        case .critico, .proximo: contrato.diasRestantes == 0 ? "Vence hoy" : "Vence en \(contrato.diasRestantes) días"
        default: "Vigente"
        }
    }
}

enum FormatoFecha {
    static let corta = Date.FormatStyle.dateTime.day().month(.abbreviated).year().locale(Formato.locale)
    static let larga = Date.FormatStyle.dateTime.day().month(.wide).year().locale(Formato.locale)

    static func rango(_ inicio: Date, _ fin: Date) -> String {
        "\(inicio.formatted(corta)) – \(fin.formatted(corta))"
    }
}
