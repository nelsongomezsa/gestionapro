import SwiftUI

@main
struct GestionApProApp: App {
    @UIApplicationDelegateAdaptor(DelegadoApp.self) private var delegado
    @State private var sesion: SesionStore

    init() {
        #if DEBUG
        // Para los UI tests de capturas: empezar siempre desde el login.
        if ProcessInfo.processInfo.arguments.contains("-reiniciarSesion") {
            KeychainTokenStore().borrar()
        }
        #endif
        _sesion = State(initialValue: SesionStore())
    }

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(sesion)
                // El token de push se manda a la API cuando llega y cada vez que hay sesión.
                .onReceive(NotificationCenter.default.publisher(for: .tokenPushRecibido)) { _ in
                    Task { await sesion.registrarDispositivo() }
                }
        }
    }
}
