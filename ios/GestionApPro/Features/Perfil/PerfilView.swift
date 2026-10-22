import SwiftUI

struct PerfilView: View {
    @Environment(SesionStore.self) private var sesion
    let usuario: Usuario

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Nombre", value: usuario.nombre)
                    LabeledContent("Email", value: usuario.email)
                    LabeledContent("Rol", value: usuario.rol.nombreVisible)
                }

                if usuario.rol == .inquilino {
                    Section {
                        ContentUnavailableView("Próximamente", systemImage: "hammer",
                                               description: Text("Pronto podrás ver aquí tu habitación, tu contrato y tus pagos."))
                    }
                }

                Section {
                    Button("Cerrar sesión", role: .destructive) { sesion.cerrarSesion() }
                }

                Section {
                    LabeledContent("Servidor", value: sesion.api.baseURL.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Perfil")
        }
    }
}
