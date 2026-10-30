import SwiftUI

/// Secciones de la pestaña "Más". Toda la navegación de la app es por valor
/// (`navigationDestination(for:)`): mezclarla con enlaces de vista dentro de la misma pila
/// hacía que algunos enlaces de las pantallas abiertas desde aquí no navegaran.
enum SeccionMas: Hashable {
    case perfil, inquilinos, contratos, calendario, estadisticas, calculadora, usuarios
}

/// Pestaña "Más": el resto de secciones del escritorio.
struct MasView: View {
    let usuario: Usuario

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(value: SeccionMas.perfil) {
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
                    enlace("Inquilinos", icono: "person.2", color: .blue, a: .inquilinos)
                    enlace("Contratos", icono: "doc.text", color: .indigo, a: .contratos)
                    enlace("Calendario", icono: "calendar", color: .red, a: .calendario)
                    enlace("Estadísticas", icono: "chart.xyaxis.line", color: .teal, a: .estadisticas)
                }

                Section("Herramientas") {
                    enlace("Calculadora de rentabilidad", icono: "function", color: .purple, a: .calculadora)
                }

                if usuario.rol == .admin {
                    Section("Administración") {
                        enlace("Usuarios", icono: "person.badge.key", color: .gray, a: .usuarios)
                    }
                }
            }
            .navigationTitle("Más")
            .navigationDestination(for: SeccionMas.self) { destino(de: $0) }
        }
    }

    @ViewBuilder
    private func destino(de seccion: SeccionMas) -> some View {
        switch seccion {
        case .perfil: PerfilView(usuario: usuario)
        case .inquilinos: InquilinosView()
        case .contratos: ContratosView()
        case .calendario: CalendarioView()
        case .estadisticas: EstadisticasView()
        case .calculadora: CalculadoraView()
        case .usuarios: UsuariosView()
        }
    }

    private func enlace(_ titulo: String, icono: String, color: Color, a seccion: SeccionMas) -> some View {
        NavigationLink(value: seccion) {
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
