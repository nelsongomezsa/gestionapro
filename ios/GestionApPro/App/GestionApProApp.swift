import SwiftUI

@main
struct GestionApProApp: App {
    @State private var sesion = SesionStore()

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(sesion)
        }
    }
}
