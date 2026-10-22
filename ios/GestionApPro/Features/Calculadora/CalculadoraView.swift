import SwiftUI

struct CalculadoraView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = CalculadoraViewModel()

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Form {
                Section {
                    Picker("Comunidad", selection: $vm.entrada.comunidad) {
                        if vm.comunidades.isEmpty {
                            Text(vm.entrada.comunidad).tag(vm.entrada.comunidad)
                        }
                        ForEach(vm.comunidades, id: \.nombre) { c in
                            Text(c.nombre).tag(c.nombre)
                        }
                    }
                    if let tipo = vm.tipoItpSeleccionado {
                        LabeledContent("ITP", value: Formato.porcentaje(tipo))
                    }
                } header: {
                    Text("Impuesto de transmisiones")
                } footer: {
                    if let anio = vm.anioReferenciaItp { Text("Tipos generales · \(anio)") }
                }

                Section("Compra") {
                    CampoImporte("Precio de compra", valor: $vm.entrada.precioCompra)
                    CampoImporte("Notaría y registro", valor: $vm.entrada.gastosNotariaRegistro)
                    CampoImporte("Gastos de hipoteca", valor: $vm.entrada.gastosHipoteca)
                    CampoImporte("Reforma", valor: $vm.entrada.reforma)
                    CampoImporte("Comisión de compra", valor: $vm.entrada.comisionCompra)
                    CampoImporte("Mobiliario", valor: $vm.entrada.mobiliario)
                }

                Section("Gastos mensuales") {
                    CampoImporte("IBI y tasas", valor: $vm.entrada.ibiMensual)
                    CampoImporte("Seguros", valor: $vm.entrada.segurosMensual)
                    CampoImporte("Comunidad", valor: $vm.entrada.comunidadMensual)
                    CampoImporte("Mantenimiento", valor: $vm.entrada.mantenimientoMensual)
                    CampoImporte("Periodos sin alquilar", valor: $vm.entrada.vacioMensual)
                }

                Section("Ingresos") {
                    CampoImporte("Alquiler mensual", valor: $vm.entrada.alquilerMensual)
                    CampoNumero("Revalorización anual", valor: $vm.entrada.revalorizacionAnualPct, sufijo: "%")
                }

                Section("Financiación") {
                    CampoNumero("Financiado", valor: $vm.entrada.porcentajeFinanciado, sufijo: "%")
                    Stepper(value: $vm.entrada.plazoAnos, in: 0...50) {
                        LabeledContent("Plazo", value: "\(vm.entrada.plazoAnos) años")
                    }
                    CampoNumero("Tipo de interés", valor: $vm.entrada.tipoInteresPct, sufijo: "%")
                }

                if let error = vm.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await vm.calcular(con: sesion.api) }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.calculando { ProgressView() } else { Text("Calcular rentabilidad").bold() }
                            Spacer()
                        }
                    }
                    .disabled(vm.calculando)
                }
            }
            .navigationTitle("Calculadora")
            .navigationDestination(item: $vm.resultado) { ResultadoRentabilidadView(resultado: $0, comunidad: vm.entrada.comunidad) }
            .task { await vm.cargarComunidades(con: sesion.api) }
        }
    }
}

/// Campo numérico con formato español (admite coma decimal).
private struct CampoNumero: View {
    let titulo: String
    @Binding var valor: Double
    var sufijo: String

    init(_ titulo: String, valor: Binding<Double>, sufijo: String) {
        self.titulo = titulo
        self._valor = valor
        self.sufijo = sufijo
    }

    var body: some View {
        LabeledContent(titulo) {
            HStack(spacing: 4) {
                TextField(titulo, value: $valor, format: .number.locale(Formato.locale))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text(sufijo).foregroundStyle(.secondary)
            }
        }
    }
}

private struct CampoImporte: View {
    let titulo: String
    @Binding var valor: Double

    init(_ titulo: String, valor: Binding<Double>) {
        self.titulo = titulo
        self._valor = valor
    }

    var body: some View {
        CampoNumero(titulo, valor: $valor, sufijo: "€")
    }
}
