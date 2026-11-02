import AppIntents
import Observation

/// Acción pedida desde Siri, Spotlight o el botón de Acción: la app se abre y la pestaña principal
/// muestra la hoja correspondiente (solo propietario y admin; con la sesión cerrada espera al login).
@MainActor
@Observable
final class AccionPendiente {
    static let compartida = AccionPendiente()
    var acceso: AccesoRapido?

    /// Devuelve la acción pendiente y la borra (se consume una sola vez).
    func tomar() -> AccesoRapido? {
        defer { acceso = nil }
        return acceso
    }
}

struct RegistrarPagoIntent: AppIntent {
    static let title: LocalizedStringResource = "Registrar un pago"
    static let description = IntentDescription("Abre GestionAp con los cobros pendientes del mes.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        AccionPendiente.compartida.acceso = .pago
        return .result()
    }
}

struct NuevaIncidenciaIntent: AppIntent {
    static let title: LocalizedStringResource = "Nueva incidencia"
    static let description = IntentDescription("Abre GestionAp para comunicar una incidencia.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        AccionPendiente.compartida.acceso = .incidencia
        return .result()
    }
}

struct AbrirMensajesIntent: AppIntent {
    static let title: LocalizedStringResource = "Mensajes con inquilinos"
    static let description = IntentDescription("Abre las conversaciones con tus inquilinos.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        AccionPendiente.compartida.acceso = .mensajes
        return .result()
    }
}

/// Atajos que aparecen en Siri, Spotlight y la app Atajos sin que el usuario tenga que crearlos.
struct AtajosGestionAp: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RegistrarPagoIntent(),
                    phrases: ["Registrar un pago en \(.applicationName)", "Cobrar un alquiler con \(.applicationName)"],
                    shortTitle: "Registrar pago", systemImageName: "eurosign.circle")
        AppShortcut(intent: NuevaIncidenciaIntent(),
                    phrases: ["Nueva incidencia en \(.applicationName)"],
                    shortTitle: "Nueva incidencia", systemImageName: "wrench.and.screwdriver")
        AppShortcut(intent: AbrirMensajesIntent(),
                    phrases: ["Ver mensajes de \(.applicationName)"],
                    shortTitle: "Mensajes", systemImageName: "bubble.left.and.bubble.right")
    }
}
