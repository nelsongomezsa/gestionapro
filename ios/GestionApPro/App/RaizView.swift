import SwiftUI

/// Login o pestañas según la sesión y el rol.
struct RaizView: View {
    @Environment(SesionStore.self) private var sesion

    var body: some View {
        Group {
            switch sesion.estado {
            case .comprobando:
                ProgressView("Cargando…")
            case .sinSesion:
                LoginView()
            case let .errorAlRestaurar(mensaje):
                ContentUnavailableView {
                    Label("No se pudo conectar", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(mensaje)
                } actions: {
                    Button("Reintentar") { Task { await sesion.restaurar() } }
                        .buttonStyle(.borderedProminent)
                    Button("Cerrar sesión", role: .destructive) { sesion.cerrarSesion() }
                }
            case let .conectado(usuario):
                PestanasView(usuario: usuario)
            }
        }
        .task { await sesion.restaurar() }
    }
}

struct PestanasView: View {
    let usuario: Usuario

    var body: some View {
        TabView {
            if usuario.rol.gestionaPisos {
                PisosListaView()
                    .tabItem { Label("Mis Pisos", systemImage: "building.2") }
                CalculadoraView()
                    .tabItem { Label("Calculadora", systemImage: "function") }
            }
            PerfilView(usuario: usuario)
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
        }
    }
}
