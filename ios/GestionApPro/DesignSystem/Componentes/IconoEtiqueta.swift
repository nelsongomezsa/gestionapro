import SwiftUI

/// Icono de SF Symbols dentro de un cuadrado redondeado con el tono de fondo suavizado.
/// Mismo peso y tamaño en toda la app (filas, KPIs y secciones).
struct IconoEtiqueta: View {
    let icono: String
    var tono: Tono = .primario
    var tamano: CGFloat = Tema.Tamano.icono

    var body: some View {
        Image(systemName: icono)
            .font(.system(size: tamano * 0.45, weight: .semibold))
            .foregroundStyle(tono.color)
            .frame(width: tamano, height: tamano)
            .background(tono.color.opacity(0.14), in: .rect(cornerRadius: Tema.Radio.pequeno))
            .accessibilityHidden(true)
    }
}

/// Bloque con título y tarjeta. El título puede llevar una acción a la derecha ("Ver todo").
struct SeccionTarjeta<Contenido: View, Accion: View>: View {
    let titulo: String
    @ViewBuilder var accion: Accion
    @ViewBuilder var contenido: Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo)
                    .font(Tema.Fuente.tituloSeccion)
                    .foregroundStyle(Tema.Color.texto)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                accion.font(Tema.Fuente.detalle)
            }
            .padding(.horizontal, Tema.Espacio.xxs)
            VStack(alignment: .leading, spacing: Tema.Espacio.s) { contenido }
                .tarjeta()
        }
    }
}

extension SeccionTarjeta where Accion == EmptyView {
    init(titulo: String, @ViewBuilder contenido: () -> Contenido) {
        self.titulo = titulo
        self.accion = EmptyView()
        self.contenido = contenido()
    }
}

/// Apariencia elegida en Perfil. Por defecto sigue al sistema.
enum Apariencia: String, CaseIterable, Identifiable {
    case sistema, oscuro, claro

    static let clave = "apariencia"
    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .sistema: "Automático"
        case .oscuro: "Oscuro"
        case .claro: "Claro"
        }
    }

    var esquema: ColorScheme? {
        switch self {
        case .sistema: nil
        case .oscuro: .dark
        case .claro: .light
        }
    }
}
