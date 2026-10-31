import LocalAuthentication
import SwiftUI

/// Entrar con Face ID: si está activado, la app se bloquea al abrirse y al volver de segundo plano,
/// y se desbloquea con Face ID (o el código del iPhone si Face ID falla). El token sigue en el Keychain:
/// esto solo protege la app abierta en un iPhone que no está en tus manos.
@MainActor @Observable
final class BloqueoBiometrico {
    static let clave = "entrarConFaceID"

    var bloqueado = false
    var error: String?

    var activado: Bool { UserDefaults.standard.bool(forKey: Self.clave) }

    /// Nombre de la biometría disponible ("Face ID", "Touch ID") o nil si no hay ninguna configurada.
    static var biometria: String? {
        let contexto = LAContext()
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return nil }
        switch contexto.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return nil
        }
    }

    func bloquearSiProcede() {
        if activado { bloqueado = true }
    }

    func desbloquear() async {
        let contexto = LAContext()
        contexto.localizedFallbackTitle = "Usar el código"
        do {
            let ok = try await contexto.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Desbloquear GestionAp")
            if ok {
                bloqueado = false
                error = nil
            }
        } catch let e as LAError where e.code == .userCancel || e.code == .appCancel || e.code == .systemCancel {
            // Cancelado: sigue bloqueada, sin mensaje.
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Pantalla de bloqueo: marca, botón para desbloquear y salida por si no se puede.
struct PantallaBloqueo: View {
    @Environment(SesionStore.self) private var sesion
    let bloqueo: BloqueoBiometrico

    var body: some View {
        VStack(spacing: Tema.Espacio.l) {
            Spacer()
            Image("Marca")
                .resizable()
                .frame(width: Tema.Tamano.logo, height: Tema.Tamano.logo)
                .clipShape(.rect(cornerRadius: Tema.Radio.tarjeta, style: .continuous))
                .accessibilityHidden(true)
            Text("GestionAp PRO está bloqueada").font(Tema.Fuente.titulo).multilineTextAlignment(.center)
            if let e = bloqueo.error {
                Text(e).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.negativo).multilineTextAlignment(.center)
            }
            BotonPrincipal(titulo: "Desbloquear con \(BloqueoBiometrico.biometria ?? "el código")", icono: "faceid") {
                Task { await bloqueo.desbloquear() }
            }
            .accessibilityIdentifier("botonDesbloquear")
            Spacer()
            Button("Cerrar sesión", role: .destructive) {
                bloqueo.bloqueado = false
                sesion.cerrarSesion()
            }
            .font(Tema.Fuente.detalle)
        }
        .padding(Tema.Espacio.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tema.Color.fondo)
        .task { await bloqueo.desbloquear() }
    }
}
