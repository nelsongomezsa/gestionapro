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
                        SelectorMes(mes: vm.mes, maximo: .actual) { nuevo in Task { await vm.cambiarMes(nuevo, con: sesion.api) } }
                        ResumenCobros(resumen: r)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    Section {
                        if r.pendientes.isEmpty {
                            Label("Todos los contratos del mes tienen algún pago", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Tema.Color.positivo)
                        }
                        ForEach(r.pendientes.filter { vm.filtroInquilino == nil || $0.inquilino.id == vm.filtroInquilino }) { p in
                            HStack {
                                VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                                    Text(p.inquilino.nombre).font(Tema.Fuente.subtitulo)
                                    Text("Hab. \(p.numeroHabitacion) · \(p.piso.direccion)")
                                        .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario).lineLimit(1)
                                }
                                Spacer()
                                Text(Formato.euros(p.importe)).font(Tema.Fuente.cifraPequena)
                                Button("Registrar") {
                                    nuevoPago = PagoPrellenado(idContrato: p.idContrato, importe: p.importe)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    } header: {
                        Text("Pendientes de cobro (\(r.pendientes.count))")
                    } footer: {
                        Text("Contratos vigentes en el mes sin ningún pago registrado.")
                    }

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
                            Text("Pagos (\(vm.pagosVisibles.count))")
                            Spacer()
                            Text(Formato.euros(vm.totalVisible)).monospacedDigit()
                        }
                    }
                }
            }
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
            Text(mes.nombre).font(Tema.Fuente.subtitulo).contentTransition(.numericText())
            Spacer()
            Button { cambiar(mes.siguiente) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Mes siguiente")
                .disabled(maximo.map { mes >= $0 } ?? false)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .padding(.bottom, Tema.Espacio.s)
    }
}

struct ResumenCobros: View {
    let resumen: ResumenPagos

    private var progreso: Double {
        resumen.esperado > 0 ? min(1, resumen.cobrado.double / resumen.esperado.double) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.m) {
            VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
                Text("Cobrado en \(resumen.nombreMes)").font(Tema.Fuente.detalle).foregroundStyle(.white.opacity(0.85))
                Text(Formato.euros(resumen.cobrado))
                    .font(Tema.Fuente.cifraGrande).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            ProgressView(value: progreso).tint(.white)
            HStack {
                dato("Esperado", Formato.euros(resumen.esperado))
                Spacer()
                dato("Pendiente", Formato.euros(resumen.pendiente))
                Spacer()
                dato("Pagos", "\(resumen.numeroPagos)")
            }
        }
        .padding(Tema.Espacio.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Color.degradadoMarca, in: .rect(cornerRadius: Tema.Radio.tarjeta))
        .accessibilityElement(children: .combine)
    }

    private func dato(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
            Text(titulo).font(Tema.Fuente.nota).foregroundStyle(.white.opacity(0.8))
            Text(valor).font(Tema.Fuente.cifraPequena).foregroundStyle(.white)
        }
    }
}

struct FilaPago: View {
    let pago: Pago

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(pago.inquilino.nombre).font(Tema.Fuente.subtitulo)
                Text("\(pago.fechaPago.formatted(FormatoFecha.corta)) · \(pago.metodoPago.nombre) · Hab. \(pago.numeroHabitacion)")
                    .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario).lineLimit(1)
            }
            Spacer()
            Text(Formato.euros(pago.cantidad)).font(Tema.Fuente.cifraPequena).foregroundStyle(Tema.Color.positivo)
        }
        .accessibilityElement(children: .combine)
    }
}
