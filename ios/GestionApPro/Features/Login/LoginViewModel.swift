import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var cargando = false
    private(set) var error: String?

    var puedeEnviar: Bool {
        !cargando && !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    func entrar(con sesion: SesionStore) async {
        guard puedeEnviar else { return }
        cargando = true
        error = nil
        defer { cargando = false }
        do {
            try await sesion.iniciarSesion(email: email.trimmingCharacters(in: .whitespaces), password: password)
            password = ""
        } catch {
            self.error = error.localizedDescription
        }
    }
}
