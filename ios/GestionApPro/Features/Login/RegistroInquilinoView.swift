import SwiftUI

/// Alta del inquilino con el código de invitación que le da su propietario
/// (se genera desde su ficha). Al terminar queda con la sesión iniciada.
struct RegistroInquilinoView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar

    @State private var codigo = ""
    @State private var email = ""
    @State private var password = ""
    @State private var repetida = ""
    @State private var enviando = false
    @State private var error: String?

    private var problema: String? {
        if codigo.trimmingCharacters(in: .whitespaces).isEmpty || !email.contains("@") || password.isEmpty { return "" }
        if password.count < 8 { return "La contraseña debe tener al menos 8 caracteres" }
        if password != repetida { return "Las contraseñas no coinciden" }
        return nil
    }

    var body: some View {
        Form {
            Section {
                TextField("Código de invitación", text: $codigo, prompt: Text("K7M2-QX9P-4TBW"))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(Tema.Fuente.cuerpo.monospaced())
                    .accessibilityIdentifier("campoCodigo")
            } footer: {
                Text("Te lo da tu propietario. Caduca a los pocos días; si no funciona, pídele uno nuevo.")
            }
            .filaLista()
            Section {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Contraseña", text: $password).textContentType(.newPassword)
                SecureField("Repite la contraseña", text: $repetida).textContentType(.newPassword)
            } footer: {
                if let p = problema, !p.isEmpty, !repetida.isEmpty {
                    Text(p).foregroundStyle(Tema.Color.aviso)
                } else {
                    Text("Mínimo 8 caracteres.")
                }
            }
            .filaLista()
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                .filaLista()
            }
        }
        .estiloLista()
        .navigationTitle("Crear mi cuenta")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
            ToolbarItem(placement: .confirmationAction) {
                if enviando { ProgressView() } else {
                    Button("Crear") { Task { await registrar() } }.disabled(problema != nil)
                }
            }
        }
    }

    private func registrar() async {
        enviando = true
        defer { enviando = false }
        do {
            try await sesion.registrarInquilino(codigo: codigo.trimmingCharacters(in: .whitespaces).uppercased(),
                                                email: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
