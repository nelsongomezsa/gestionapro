import SwiftUI

/// Alta o edición de una habitación.
struct HabitacionFormView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar

    let piso: PisoBreve
    let habitacion: Habitacion?
    let alGuardar: (Habitacion) -> Void

    @State private var numero = 1
    @State private var precio = 0.0
    @State private var estado: EstadoHabitacion = .disponible
    @State private var guardando = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Piso", value: piso.direccion)
                    Stepper(value: $numero, in: 1...999) {
                        LabeledContent("Número", value: "\(numero)")
                    }
                    CampoNumerico("Precio mensual", valor: $precio, sufijo: "€")
                    Picker("Estado", selection: $estado) {
                        ForEach(EstadoHabitacion.allCases) { Label($0.nombre, systemImage: $0.icono).tag($0) }
                    }
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                }
            }
            .navigationTitle(habitacion == nil ? "Nueva habitación" : "Habitación \(habitacion!.numero)")
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
        if let h = habitacion {
            numero = h.numero
            precio = h.precio.double
            estado = h.estado
        }
    }

    private func guardar() async {
        guardando = true
        defer { guardando = false }
        let req = HabitacionRequest(idPiso: piso.id, numero: numero,
                                    precio: Decimal(string: String(format: "%.2f", precio)) ?? 0, estado: estado)
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
