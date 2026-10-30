import SwiftUI
import UIKit

/// Tokens de diseño de GestionApPro: color, tipografía, espaciado y radios.
/// El color principal es el morado del icono (#6C63FF), más claro en modo oscuro.
enum Tema {

    // MARK: Color

    enum Color {
        static let primario = SwiftUI.Color.accentColor
        static let primarioSuave = SwiftUI.Color.accentColor.opacity(0.12)

        static let positivo = dinamico(claro: 0x1E9E5A, oscuro: 0x3DD68C)
        static let negativo = dinamico(claro: 0xD93A3A, oscuro: 0xFF6B6B)
        static let aviso = dinamico(claro: 0xC77700, oscuro: 0xFFB340)
        static let neutro = SwiftUI.Color(uiColor: .secondaryLabel)

        static let fondo = SwiftUI.Color(uiColor: .systemGroupedBackground)
        static let superficie = SwiftUI.Color(uiColor: .secondarySystemGroupedBackground)
        static let superficieElevada = SwiftUI.Color(uiColor: .tertiarySystemGroupedBackground)
        static let borde = SwiftUI.Color(uiColor: .separator).opacity(0.6)
        static let textoSecundario = SwiftUI.Color(uiColor: .secondaryLabel)

        /// Degradado de la marca (cabeceras y avatar).
        static let degradadoMarca = LinearGradient(
            colors: [dinamico(claro: 0x6C63FF, oscuro: 0x8A82FF), dinamico(claro: 0x4A3FD1, oscuro: 0x5B50E0)],
            startPoint: .topLeading, endPoint: .bottomTrailing)

        private static func dinamico(claro: UInt32, oscuro: UInt32) -> SwiftUI.Color {
            SwiftUI.Color(uiColor: UIColor { rasgos in
                UIColor(hex: rasgos.userInterfaceStyle == .dark ? oscuro : claro)
            })
        }
    }

    // MARK: Tipografía
    // Cifras en SF Rounded con dígitos de ancho fijo, para que las columnas de importes alineen.

    enum Fuente {
        static let cifraGrande = Font.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit()
        static let cifra = Font.system(.title2, design: .rounded, weight: .semibold).monospacedDigit()
        static let cifraMediana = Font.system(.title3, design: .rounded, weight: .semibold).monospacedDigit()
        static let cifraPequena = Font.system(.headline, design: .rounded, weight: .semibold).monospacedDigit()
        static let titulo = Font.title2.weight(.bold)
        static let subtitulo = Font.headline
        static let cuerpo = Font.body
        static let detalle = Font.subheadline
        static let etiqueta = Font.caption.weight(.semibold)
        static let nota = Font.caption
    }

    // MARK: Espaciado (escala de 4 pt)

    enum Espacio {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Radios

    enum Radio {
        static let pequeno: CGFloat = 8
        static let medio: CGFloat = 12
        static let grande: CGFloat = 16
        static let tarjeta: CGFloat = 20
    }
}

/// Tono semántico de un dato o estado.
enum Tono: Sendable {
    case primario, positivo, negativo, aviso, neutro

    var color: Color {
        switch self {
        case .primario: Tema.Color.primario
        case .positivo: Tema.Color.positivo
        case .negativo: Tema.Color.negativo
        case .aviso: Tema.Color.aviso
        case .neutro: Tema.Color.neutro
        }
    }

    /// Positivo, negativo o neutro según el signo.
    static func signo(_ valor: Decimal) -> Tono {
        valor > 0 ? .positivo : (valor < 0 ? .negativo : .neutro)
    }

    static func signo(_ valor: Double?) -> Tono {
        guard let valor else { return .neutro }
        return valor > 0 ? .positivo : (valor < 0 ? .negativo : .neutro)
    }
}

extension View {
    /// Contenedor de tarjeta: superficie, radio grande y borde fino (sombra solo en modo claro).
    func tarjeta(relleno: CGFloat = Tema.Espacio.m) -> some View {
        modifier(EstiloTarjeta(relleno: relleno))
    }

    /// Etiqueta en mayúsculas con algo de espaciado entre letras.
    func estiloEtiqueta() -> some View {
        font(Tema.Fuente.etiqueta)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(Tema.Color.textoSecundario)
    }
}

private struct EstiloTarjeta: ViewModifier {
    let relleno: CGFloat
    @Environment(\.colorScheme) private var esquema

    func body(content: Content) -> some View {
        content
            .padding(relleno)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tema.Color.superficie, in: .rect(cornerRadius: Tema.Radio.tarjeta))
            // El borde va encima: sin allowsHitTesting(false) se tragaba los toques de los
            // enlaces y botones que hay dentro de la tarjeta.
            .overlay(RoundedRectangle(cornerRadius: Tema.Radio.tarjeta).strokeBorder(Tema.Color.borde, lineWidth: 0.5)
                .allowsHitTesting(false))
            .shadow(color: .black.opacity(esquema == .dark ? 0 : 0.05), radius: 8, y: 2)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
