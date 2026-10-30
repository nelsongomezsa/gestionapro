import SwiftUI

struct CalculadoraView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = CalculadoraViewModel()

    var body: some View {
        @Bindable var vm = vm
        Form {
            Section {
                ResumenRentabilidad(resultado: vm.resultado, calculando: vm.calculando)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } footer: {
                if let error = vm.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Tema.Color.negativo)
                }
            }

            Section("Impuesto de transmisiones") {
                Picker("Comunidad autónoma", selection: $vm.entrada.comunidad) {
                    if vm.comunidades.isEmpty {
                        Text(vm.entrada.comunidad).tag(vm.entrada.comunidad)
                    }
                    ForEach(vm.comunidades, id: \.nombre) { Text($0.nombre).tag($0.nombre) }
                }
                if let tipo = vm.tipoItpSeleccionado {
                    LabeledContent("Tipo de ITP", value: Formato.porcentaje(tipo))
                }
            }

            Group {
                Section("Compra") {
                    CampoNumerico("Precio de compra", valor: $vm.entrada.precioCompra, sufijo: "€")
                    CampoNumerico("Notaría y registro", valor: $vm.entrada.gastosNotariaRegistro, sufijo: "€")
                    CampoNumerico("Gastos de hipoteca", valor: $vm.entrada.gastosHipoteca, sufijo: "€")
                    CampoNumerico("Reforma", valor: $vm.entrada.reforma, sufijo: "€")
                    CampoNumerico("Comisión de compra", valor: $vm.entrada.comisionCompra, sufijo: "€")
                    CampoNumerico("Mobiliario", valor: $vm.entrada.mobiliario, sufijo: "€")
                }

                Section("Gastos mensuales") {
                    CampoNumerico("IBI y tasas", valor: $vm.entrada.ibiMensual, sufijo: "€")
                    CampoNumerico("Seguros", valor: $vm.entrada.segurosMensual, sufijo: "€")
                    CampoNumerico("Comunidad", valor: $vm.entrada.comunidadMensual, sufijo: "€")
                    CampoNumerico("Mantenimiento", valor: $vm.entrada.mantenimientoMensual, sufijo: "€")
                    CampoNumerico("Periodos sin alquilar", valor: $vm.entrada.vacioMensual, sufijo: "€")
                }

                Section("Ingresos") {
                    CampoNumerico("Alquiler mensual", valor: $vm.entrada.alquilerMensual, sufijo: "€")
                    CampoNumerico("Revalorización anual", valor: $vm.entrada.revalorizacionAnualPct, sufijo: "%")
                }

                Section("Financiación") {
                    CampoNumerico("Financiado", valor: $vm.entrada.porcentajeFinanciado, sufijo: "%")
                    Stepper(value: $vm.entrada.plazoAnos, in: 0...50) {
                        LabeledContent("Plazo", value: "\(vm.entrada.plazoAnos) años")
                    }
                    CampoNumerico("Tipo de interés", valor: $vm.entrada.tipoInteresPct, sufijo: "%")
                }
            }
            .id(vm.version)

            Section {
                BotonPrincipal(titulo: "Ver desglose completo", icono: "list.bullet.rectangle") {
                    vm.mostrarDesglose = true
                }
                .disabled(vm.resultado == nil)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Calculadora")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Limpiar", systemImage: "eraser") { vm.limpiar() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { ocultarTeclado() }
            }
        }
        .navigationDestination(isPresented: $vm.mostrarDesglose) {
            if let r = vm.resultado {
                ResultadoRentabilidadView(resultado: r, comunidad: vm.entrada.comunidad)
            }
        }
        .task { await vm.cargarComunidades(con: sesion.api) }
        .task(id: vm.entrada) { await vm.recalcularConPausa(con: sesion.api) }
    }

    private func ocultarTeclado() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Resumen que se actualiza al escribir: rentabilidades y cash flow.
private struct ResumenRentabilidad: View {
    let resultado: RentabilidadResponse?
    let calculando: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.m) {
            HStack {
                Text("Cash flow mensual")
                    .font(Tema.Fuente.detalle)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                if calculando { ProgressView().tint(.white).controlSize(.small) }
            }
            Text(resultado.map { Formato.euros($0.cashFlowMensual) } ?? "—")
                .font(Tema.Fuente.cifraGrande)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack {
                dato("Rent. bruta", Formato.porcentaje(resultado?.rentabilidadBrutaPct))
                Spacer()
                dato("Rent. neta", Formato.porcentaje(resultado?.rentabilidadNetaPct))
                Spacer()
                dato("Recuperas en", Formato.anios(resultado?.aniosRecuperacion))
            }
        }
        .padding(Tema.Espacio.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Color.degradadoMarca, in: .rect(cornerRadius: Tema.Radio.tarjeta))
        .animation(.default, value: resultado)
        .accessibilityElement(children: .combine)
    }

    private func dato(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(Tema.Fuente.nota).foregroundStyle(.white.opacity(0.8))
            Text(valor).font(Tema.Fuente.cifraPequena).foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }
}

/// Campo numérico en español: muestra "200.000", admite coma decimal y avisa del valor
/// en cada pulsación (no solo al salir del campo), para que el resumen se actualice al escribir.
struct CampoNumerico: View {
    let titulo: String
    @Binding var valor: Double
    var sufijo: String

    @State private var texto = ""
    @FocusState private var enfocado: Bool

    init(_ titulo: String, valor: Binding<Double>, sufijo: String) {
        self.titulo = titulo
        self._valor = valor
        self.sufijo = sufijo
    }

    var body: some View {
        LabeledContent(titulo) {
            HStack(spacing: Tema.Espacio.xxs) {
                TextField("0", text: $texto)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($enfocado)
                    .onChange(of: texto) { _, nuevo in
                        let limpio = nuevo.trimmingCharacters(in: .whitespaces)
                        valor = limpio.isEmpty ? 0 : (Formato.numeroEditable.number(from: limpio)?.doubleValue ?? valor)
                    }
                    .onChange(of: enfocado) { _, ahora in
                        if !ahora { texto = Self.formatear(valor) }
                    }
                Text(sufijo).foregroundStyle(Tema.Color.textoSecundario)
            }
        }
        .onAppear { texto = Self.formatear(valor) }
    }

    private static func formatear(_ v: Double) -> String {
        v == 0 ? "" : (Formato.numeroEditable.string(from: NSNumber(value: v)) ?? "")
    }
}
