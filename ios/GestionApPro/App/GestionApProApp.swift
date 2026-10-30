import SwiftUI

@main
struct GestionApProApp: App {
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
        }
    }
}
