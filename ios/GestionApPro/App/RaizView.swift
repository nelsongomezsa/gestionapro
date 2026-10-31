import SwiftUI

/// Login o pestañas según la sesión y el rol.
struct RaizView: View {
    @Environment(SesionStore.self) private var sesion
    @AppStorage(Apariencia.clave) private var apariencia: Apariencia = .sistema

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
                        .tint(Tema.Color.primarioRelleno)
                    Button("Cerrar sesión", role: .destructive) { sesion.cerrarSesion() }
                }
            case let .conectado(usuario):
                PestanasView(usuario: usuario)
            }
        }
        .preferredColorScheme(apariencia.esquema)
        .task { await sesion.restaurar() }
    }
}

/// Propietario y admin: Inicio · Pisos · Cobros · Incidencias · Más.
/// Inquilino: su alquiler y su perfil.
struct PestanasView: View {
    let usuario: Usuario

    var body: some View {
        if usuario.rol.gestionaPisos {
            TabView {
                InicioView().tabItem { Label("Inicio", systemImage: "house") }
                PisosListaView().tabItem { Label("Pisos", systemImage: "building.2") }
                CobrosView().tabItem { Label("Cobros", systemImage: "eurosign.circle") }
                IncidenciasView().tabItem { Label("Incidencias", systemImage: "wrench.and.screwdriver") }
                MasView(usuario: usuario).tabItem { Label("Más", systemImage: "ellipsis.circle") }
            }
        } else {
            TabView {
                MiAlquilerView()
                    .tabItem { Label("Mi alquiler", systemImage: "key") }
                IncidenciasView()
                    .tabItem { Label("Incidencias", systemImage: "wrench.and.screwdriver") }
                NavigationStack { ConversacionesView() }
                    .tabItem { Label("Mensajes", systemImage: "bubble.left.and.bubble.right") }
                NavigationStack { PerfilView(usuario: usuario) }
                    .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
            }
        }
    }
}
