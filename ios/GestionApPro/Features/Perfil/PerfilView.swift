import SwiftUI

struct PerfilView: View {
    @Environment(SesionStore.self) private var sesion
    let usuario: Usuario
    @State private var confirmarSalida = false

    var body: some View {
        List {
            Section {
                VStack(spacing: Tema.Espacio.s) {
                    AvatarIniciales(nombre: usuario.nombre, tamano: 84)
                    VStack(spacing: Tema.Espacio.xxs) {
                        Text(usuario.nombre).font(Tema.Fuente.titulo)
                        Text(usuario.email).foregroundStyle(Tema.Color.textoSecundario)
                    }
                    InsigniaEstado(texto: usuario.rol.nombreVisible, tono: .primario, icono: "person.badge.shield.checkmark")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tema.Espacio.s)
                .listRowBackground(Color.clear)
            }

            Section("Cuenta") {
                LabeledContent("Nombre", value: usuario.nombre)
                LabeledContent("Email", value: usuario.email)
                LabeledContent("Rol", value: usuario.rol.nombreVisible)
            }

            Section {
                Button("Cerrar sesión", role: .destructive) { confirmarSalida = true }
                    .frame(maxWidth: .infinity)
            }

            #if DEBUG
            Section("Desarrollo") {
                LabeledContent("Servidor", value: sesion.api.baseURL.absoluteString)
                    .font(Tema.Fuente.nota)
            }
            #endif
        }
        .navigationTitle("Perfil")
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmarSalida, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { sesion.cerrarSesion() }
        }
    }
}
