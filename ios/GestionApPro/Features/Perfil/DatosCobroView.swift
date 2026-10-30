import SwiftUI

/// IBAN y DNI del propietario: los usan el QR de pago y el contrato en PDF.
struct DatosCobroView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let usuario: Usuario

    @State private var iban = ""
    @State private var dni = ""
    @State private var guardando = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("IBAN", text: $iban, prompt: Text("ES00 0000 0000 0000 0000 0000"))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
            } header: {
                Text("Cuenta para los cobros")
            } footer: {
                Text("Se usa en el QR de pago SEPA que generas para tus inquilinos. Se comprueban los dígitos de control.")
            }
            Section {
                TextField("DNI o NIE", text: $dni)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            } header: {
                Text("Identificación")
            } footer: {
                Text("Aparece como arrendador en los contratos en PDF.")
            }
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
            }
        }
        .navigationTitle("Datos de cobro")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if guardando { ProgressView() } else { Button("Guardar") { Task { await guardar() } } }
            }
        }
        .onAppear {
            iban = usuario.iban ?? ""
            dni = usuario.dni ?? ""
        }
    }

    private func guardar() async {
        guardando = true
        defer { guardando = false }
        do {
            let u = try await sesion.api.enviar(.actualizarPerfil(ActualizarPerfilRequest(dni: dni, iban: iban)))
            sesion.actualizar(usuario: u)
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
