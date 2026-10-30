import SwiftUI

/// Pestaña Cobros (Pagos del escritorio): resumen del mes, pendientes y pagos registrados.
struct CobrosView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = CobrosViewModel()
    @State private var nuevoPago: PagoPrellenado?
    @State private var paraBorrar: Pago?

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            VistaCarga(estado: vm.resumen, reintentar: { Task { await vm.cargar(con: sesion.api) } }) { r in
                List {
                    Section {
                        VStack(spacing: Tema.Espacio.m) {
                            SelectorMes(mes: vm.mes, maximo: .actual) { nuevo in Task { await vm.cambiarMes(nuevo, con: sesion.api) } }
                            ResumenCobros(resumen: r)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    Section {
                        let pendientes = pendientesVisibles(r)
                        if pendientes.isEmpty {
                            Label("Todos los contratos del mes tienen algún pago", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Tema.Color.positivo)
                        }
                        ForEach(pendientes) { p in
                            HStack(alignment: .top, spacing: Tema.Espacio.s) {
                                AvatarIniciales(nombre: p.inquilino.nombre, tamano: Tema.Tamano.icono)
                                VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                                    Text(p.inquilino.nombre).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                                    Text("Hab. \(p.numeroHabitacion) · \(p.piso.direccion)")
                                        .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                                }
                                Spacer(minLength: Tema.Espacio.xs)
                                VStack(alignment: .trailing, spacing: Tema.Espacio.xs) {
                                    Text(Formato.euros(p.importe)).font(Tema.Fuente.cifraPequena).foregroundStyle(Tema.Color.texto)
                                    Button("Registrar") {
                                        nuevoPago = PagoPrellenado(idContrato: p.idContrato, importe: p.importe)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    // Relleno fijo: con el acento claro del modo oscuro el texto blanco no llegaba a 4,5:1.
                                    .tint(Tema.Color.primarioRelleno)
                                    .controlSize(.small)
                                    .accessibilityLabel("Registrar pago de \(p.inquilino.nombre)")
                                }
                            }
                            .padding(.vertical, Tema.Espacio.xxs)
                        }
                    } header: {
                        Text("Pendientes de cobro (\(pendientesVisibles(r).count))")
                    } footer: {
                        Text("Contratos vigentes en el mes sin ningún pago registrado.")
                    }
                    .filaLista()

                    Section {
                        if vm.pagosVisibles.isEmpty {
                            Text("Sin pagos registrados").foregroundStyle(Tema.Color.textoSecundario)
                        }
                        ForEach(vm.pagosVisibles) { p in
                            FilaPago(pago: p)
                                .swipeActions { Button("Borrar", systemImage: "trash", role: .destructive) { paraBorrar = p } }
                        }
                    } header: {
                        HStack {
                            Text("Pagos registrados (\(vm.pagosVisibles.count))")
                            Spacer()
                            // El total del mes ya está arriba; aquí solo cuando se filtra.
                            if vm.filtroInquilino != nil || !vm.busqueda.isEmpty {
                                Text(Formato.euros(vm.totalVisible)).monospacedDigit()
                            }
                        }
                    }
                    .filaLista()
                }
                .estiloLista()
            }
            .background(Tema.Color.fondo)
            .navigationTitle("Cobros")
            .searchable(text: $vm.busqueda, prompt: "Inquilino, dirección o habitación")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Registrar pago", systemImage: "plus") { nuevoPago = PagoPrellenado(idContrato: nil, importe: nil) }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Picker("Inquilino", selection: $vm.filtroInquilino) {
                        Text("Todos los inquilinos").tag(Int?.none)
                        ForEach(vm.inquilinosDelMes, id: \.id) { Text($0.nombre).tag(Int?.some($0.id)) }
                    }
                }
            }
            .refreshable { await vm.cargar(con: sesion.api) }
            .task { await vm.cargar(con: sesion.api) }
            .sheet(item: $nuevoPago) { p in
                PagoFormView(idContrato: p.idContrato, importe: p.importe) { _ in Task { await vm.cargar(con: sesion.api) } }
            }
            .confirmationDialog("¿Borrar el pago de \(paraBorrar.map { Formato.euros($0.cantidad) } ?? "")?",
                                isPresented: Binding(get: { paraBorrar != nil }, set: { if !$0 { paraBorrar = nil } }),
                                titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { if let p = paraBorrar { Task { await vm.borrar(p, con: sesion.api) } } }
            }
            .alertaError($vm.error)
        }
    }

    /// Pendientes del mes con el filtro de inquilino aplicado (filas y contador salen de aquí).
    private func pendientesVisibles(_ r: ResumenPagos) -> [ResumenPagos.Pendiente] {
        r.pendientes.filter { vm.filtroInquilino == nil || $0.inquilino.id == vm.filtroInquilino }
    }
}

struct PagoPrellenado: Identifiable {
    let id = UUID()
    let idContrato: Int?
    let importe: Decimal?
}

/// "‹ Octubre 2026 ›"
struct SelectorMes: View {
    let mes: Mes
    var maximo: Mes? = nil
    let cambiar: (Mes) -> Void

    var body: some View {
        HStack {
            Button { cambiar(mes.anterior) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Mes anterior")
            Spacer()
            Text(mes.nombre)
                .font(Tema.Fuente.subtitulo)
                .foregroundStyle(Tema.Color.texto)
                .contentTransition(.numericText())
            Spacer()
            Button { cambiar(mes.siguiente) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Mes siguiente")
                .disabled(maximo.map { mes >= $0 } ?? false)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(Tema.Color.primario)
    }
}

/// Lo cobrado en el mes frente a lo esperado (rentas de los contratos vigentes).
/// Se usa en Cobros y en el Calendario.
struct ResumenCobros: View {
    let nombreMes: String
    let cobrado: Decimal
    let esperado: Decimal
    let pendiente: Decimal
    var numeroPagos: Int? = nil

    init(resumen: ResumenPagos) {
        self.init(nombreMes: resumen.nombreMes, cobrado: resumen.cobrado, esperado: resumen.esperado,
                  pendiente: resumen.pendiente, numeroPagos: resumen.numeroPagos)
    }

    init(nombreMes: String, cobrado: Decimal, esperado: Decimal, pendiente: Decimal, numeroPagos: Int? = nil) {
        self.nombreMes = nombreMes
        self.cobrado = cobrado
        self.esperado = esperado
        self.pendiente = pendiente
        self.numeroPagos = numeroPagos
    }

    private var progreso: Double {
        esperado > 0 ? min(1, cobrado.double / esperado.double) : 0
    }

    var body: some View {
        TarjetaHero(titulo: "Cobrado en \(nombreMes)", valor: Formato.euros(cobrado)) {
            VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                BarraProgreso(valor: progreso, tono: .positivo)
                Text("\(Formato.porcentaje(progreso * 100)) de \(Formato.euros(esperado)) esperados")
                    .font(Tema.Fuente.nota)
                    .foregroundStyle(Tema.Color.textoSecundario)
            }
            ParDatos {
                DatoCompacto(titulo: "Pendiente de cobrar", valor: Formato.euros(pendiente),
                             tono: pendiente > 0 ? .aviso : .positivo)
            } derecha: {
                if let numeroPagos {
                    DatoCompacto(titulo: "Pagos registrados", valor: "\(numeroPagos)")
                }
            }
        }
    }
}

struct FilaPago: View {
    let pago: Pago

    var body: some View {
        HStack(alignment: .top, spacing: Tema.Espacio.s) {
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(pago.inquilino.nombre).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                Text("\(pago.fechaPago.formatted(FormatoFecha.corta)) · \(pago.metodoPago.nombre) · Hab. \(pago.numeroHabitacion)")
                    .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
            Spacer(minLength: Tema.Espacio.xs)
            Text(Formato.euros(pago.cantidad))
                .font(Tema.Fuente.cifraPequena)
                .foregroundStyle(Tema.Color.positivo)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }
}
