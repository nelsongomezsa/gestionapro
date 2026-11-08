import SwiftUI

/// Alta o edición de una unidad: habitación, plaza de garaje o trastero (con m², planta y vehículo).
struct HabitacionFormView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar

    let piso: PisoBreve
    let habitacion: Habitacion?
    let alGuardar: (Habitacion) -> Void

    @State private var numero = 1
    @State private var precio = 0.0
    @State private var estado: EstadoHabitacion = .disponible
    @State private var tipo: TipoUnidad = .habitacion
    @State private var metros = 0.0
    @State private var planta = ""
    @State private var vehiculo: Vehiculo?
    @State private var guardando = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Inmueble", value: piso.direccion)
                    Stepper(value: $numero, in: 1...999) {
                        LabeledContent("Número", value: "\(numero)")
                    }
                    CampoNumerico("Precio mensual", valor: $precio, sufijo: "€")
                    Picker("Estado", selection: $estado) {
                        ForEach(EstadoHabitacion.allCases) { Label($0.nombre(para: tipo), systemImage: $0.icono).tag($0) }
                    }
                }
                .filaLista()
                if piso.tipoInmueble != .vivienda {
                    Section {
                        if piso.tipoInmueble.unidadesAdmitidas.count > 1 {
                            Picker("Tipo", selection: $tipo) {
                                ForEach(piso.tipoInmueble.unidadesAdmitidas) { Label($0.nombre, systemImage: $0.icono).tag($0) }
                            }
                            .accessibilityIdentifier("tipoUnidad")
                        }
                        CampoNumerico("Superficie", valor: $metros, sufijo: "m²")
                        TextField("Planta (p. ej. -1)", text: $planta)
                            .onChange(of: planta) { _, v in if v.count > 20 { planta = String(v.prefix(20)) } }
                        if tipo == .plaza {
                            Picker("Para", selection: $vehiculo) {
                                Text("Sin indicar").tag(Vehiculo?.none)
                                ForEach(Vehiculo.allCases) { Label($0.nombre, systemImage: $0.icono).tag(Vehiculo?.some($0)) }
                            }
                        }
                    } footer: {
                        Text("Opcional.")
                    }
                    .filaLista()
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                    .filaLista()
                }
            }
            .estiloLista()
            .navigationTitle(habitacion.map(\.titulo) ?? tipo.nueva)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if guardando { ProgressView() } else {
                        Button("Guardar") { Task { await guardar() } }.disabled(precio <= 0)
                    }
                }
            }
            .onAppear(perform: rellenar)
        }
    }

    private func rellenar() {
        tipo = piso.tipoInmueble.unidad
        if let h = habitacion {
            numero = h.numero
            precio = h.precio.double
            estado = h.estado
            tipo = h.unidad
            metros = h.metros?.double ?? 0
            planta = h.planta ?? ""
            vehiculo = h.vehiculo
        }
    }

    private func guardar() async {
        guardando = true
        defer { guardando = false }
        let plantaLimpia = planta.trimmingCharacters(in: .whitespaces)
        let req = HabitacionRequest(idPiso: piso.id, numero: numero,
                                    precio: Decimal(string: String(format: "%.2f", precio)) ?? 0, estado: estado,
                                    tipo: tipo,
                                    metros: metros > 0 ? Decimal(string: String(format: "%.2f", metros)) : nil,
                                    planta: plantaLimpia.isEmpty ? nil : plantaLimpia,
                                    vehiculo: tipo == .plaza ? vehiculo : nil)
        do {
            let h = try await sesion.api.enviar(habitacion == nil ? .crearHabitacion(req) : .actualizarHabitacion(id: habitacion!.id, req))
            alGuardar(h)
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
