import SwiftUI

/// Secciones de la pestaña "Más". Toda la navegación de la app es por valor
/// (`navigationDestination(for:)`): mezclarla con enlaces de vista dentro de la misma pila
/// hacía que algunos enlaces de las pantallas abiertas desde aquí no navegaran.
enum SeccionMas: Hashable {
    case perfil, inquilinos, contratos, mensajes, calendario, estadisticas, calculadora, usuarios
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
                            AvatarIniciales(nombre: usuario.nombre, tamano: Tema.Tamano.avatarMedio)
                            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
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
                .filaLista()

                Section("Gestión") {
                    enlace("Inquilinos", icono: "person.2", color: Tema.Color.iconoAzul, a: .inquilinos)
                    enlace("Contratos", icono: "doc.text", color: Tema.Color.iconoAzul, a: .contratos)
                    enlace("Mensajes", icono: "bubble.left.and.bubble.right", color: Tema.Color.iconoAzul, a: .mensajes)
                    enlace("Calendario", icono: "calendar", color: Tema.Color.iconoAzul, a: .calendario)
                    enlace("Estadísticas", icono: "chart.xyaxis.line", color: Tema.Color.iconoAzul, a: .estadisticas)
                }
                .filaLista()

                Section("Herramientas") {
                    enlace("Calculadora de rentabilidad", icono: "function", color: Tema.Color.iconoMarino, a: .calculadora)
                }
                .filaLista()

                if usuario.rol == .admin {
                    Section("Administración") {
                        enlace("Usuarios", icono: "person.badge.key", color: Tema.Color.iconoMarino, a: .usuarios)
                    }
                    .filaLista()
                }
            }
            .estiloLista()
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
        case .mensajes: ConversacionesView()
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
                IconoSeccion(icono: icono, relleno: color)
            }
        }
    }
}

/// Círculo con las iniciales del nombre sobre el azul de la marca.
struct AvatarIniciales: View {
    let nombre: String
    var tamano: CGFloat = 64

    private var iniciales: String {
        nombre.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        Text(iniciales.isEmpty ? "?" : iniciales)
            .font(.system(size: tamano * 0.38, weight: .semibold))
            .foregroundStyle(Tema.Color.sobrePrimario)
            .frame(width: tamano, height: tamano)
            .background(Tema.Color.primarioRelleno, in: .circle)
            .accessibilityHidden(true)
    }
}
