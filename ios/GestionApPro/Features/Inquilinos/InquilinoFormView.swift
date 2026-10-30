import SwiftUI

/// Alta o edición de un inquilino, con las mismas reglas que el escritorio (más NIE).
struct InquilinoFormView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar

    let inquilino: Inquilino?
    let alGuardar: (Inquilino) -> Void

    @State private var datos = InquilinoRequest()
    @State private var guardando = false
    @State private var error: String?

    private var dniValido: Bool {
        datos.dni.range(of: #"^([0-9]{8}|[XYZxyz][0-9]{7})[A-Za-z]$"#, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos personales") {
                    TextField("Nombre", text: $datos.nombre).textContentType(.givenName)
                    TextField("Apellidos", text: $datos.apellidos).textContentType(.familyName)
                    TextField("DNI o NIE", text: $datos.dni)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section {
                    TextField("Teléfono", text: $datos.telefono).keyboardType(.phonePad).textContentType(.telephoneNumber)
                    TextField("Email", text: $datos.email)
                        .keyboardType(.emailAddress).textContentType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: {
                    Text("Contacto")
                } footer: {
                    Text("Opcionales. El teléfono permite llamar o escribir por WhatsApp desde la ficha.")
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                }
            }
            .navigationTitle(inquilino == nil ? "Nuevo inquilino" : "Editar inquilino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if guardando { ProgressView() } else {
                        Button("Guardar") { Task { await guardar() } }
                            .disabled(datos.nombre.trimmingCharacters(in: .whitespaces).isEmpty
                                      || datos.apellidos.trimmingCharacters(in: .whitespaces).isEmpty || !dniValido)
                    }
                }
            }
            .onAppear {
                if let i = inquilino {
                    datos = InquilinoRequest(nombre: i.nombre, apellidos: i.apellidos, dni: i.dni,
                                             telefono: i.telefono ?? "", email: i.email ?? "")
                }
            }
        }
    }

    private func guardar() async {
        guardando = true
        defer { guardando = false }
        do {
            let i = try await sesion.api.enviar(inquilino == nil ? .crearInquilino(datos) : .actualizarInquilino(id: inquilino!.id, datos))
            alGuardar(i)
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
