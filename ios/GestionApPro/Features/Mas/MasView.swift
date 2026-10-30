import SwiftUI

/// Pestaña "Más": el resto de secciones del escritorio.
struct MasView: View {
    let usuario: Usuario

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { PerfilView(usuario: usuario) } label: {
                        HStack(spacing: Tema.Espacio.s) {
                            AvatarIniciales(nombre: usuario.nombre, tamano: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(usuario.nombre).font(Tema.Fuente.subtitulo)
                                Text(usuario.email)
                                    .font(Tema.Fuente.detalle)
                                    .foregroundStyle(Tema.Color.textoSecundario)
                            }
                        }
                        .padding(.vertical, Tema.Espacio.xxs)
                    }
                    .accessibilityIdentifier("enlacePerfil")
                }

                Section("Gestión") {
                    enlace("Inquilinos", icono: "person.2", color: .blue) { PantallaPendiente(titulo: "Inquilinos", fase: "4B") }
                    enlace("Contratos", icono: "doc.text", color: .indigo) { PantallaPendiente(titulo: "Contratos", fase: "4C") }
                    enlace("Calendario", icono: "calendar", color: .red) { PantallaPendiente(titulo: "Calendario", fase: "4D") }
                    enlace("Estadísticas", icono: "chart.xyaxis.line", color: .teal) { PantallaPendiente(titulo: "Estadísticas", fase: "4D") }
                }

                Section("Herramientas") {
                    enlace("Calculadora de rentabilidad", icono: "function", color: .purple) { CalculadoraView() }
                }

                if usuario.rol == .admin {
                    Section("Administración") {
                        enlace("Usuarios", icono: "person.badge.key", color: .gray) { PantallaPendiente(titulo: "Usuarios", fase: "4F") }
                    }
                }
            }
            .navigationTitle("Más")
        }
    }

    private func enlace<Destino: View>(_ titulo: String, icono: String, color: Color,
                                       @ViewBuilder destino: @escaping () -> Destino) -> some View {
        NavigationLink(destination: destino) {
            Label {
                Text(titulo)
            } icon: {
                Image(systemName: icono)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(color.gradient, in: .rect(cornerRadius: 7))
            }
        }
    }
}

/// Círculo con las iniciales del nombre sobre el degradado de la marca.
struct AvatarIniciales: View {
    let nombre: String
    var tamano: CGFloat = 64

    private var iniciales: String {
        nombre.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        Text(iniciales.isEmpty ? "?" : iniciales)
            .font(.system(size: tamano * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: tamano, height: tamano)
            .background(Tema.Color.degradadoMarca, in: .circle)
            .accessibilityHidden(true)
    }
}
