import SwiftUI
import UIKit

/// Tokens de diseño de GestionApPro: color, tipografía, espaciado, radios y elevación.
///
/// Identidad: azul marino profundo con azul eléctrico como acento (acción principal) y verde
/// para lo positivo; rojo y ámbar solo para estados. Cada color tiene variante clara y oscura
/// y cumple contraste WCAG AA (4,5:1) sobre las superficies donde se usa: acento claro #1F5FE0
/// (5,2:1 sobre el fondo) y oscuro #5C97FF (6,0:1 sobre la superficie).
enum Tema {

    // MARK: Color

    enum Color {
        /// Azul eléctrico: enlaces, iconos y acciones. Es el color de acento del catálogo.
        static let primario = SwiftUI.Color.accentColor
        /// Fondo de los botones secundarios: el acento encima mantiene 4,9:1 (claro) y 5,2:1 (oscuro).
        static let primarioSuave = dinamico(claro: 0xEDF2FD, oscuro: 0x15274A)
        /// Relleno de los botones principales: el mismo azul en los dos modos, para que el
        /// texto blanco encima tenga contraste suficiente (5,6:1).
        static let primarioRelleno = fijo(0x1F5FE0)
        static let sobrePrimario = SwiftUI.Color.white
        /// Relleno de los botones destructivos (texto blanco encima).
        static let negativoRelleno = fijo(0xC62828)

        static let positivo = dinamico(claro: 0x15803D, oscuro: 0x3DD68C)
        static let negativo = dinamico(claro: 0xC62828, oscuro: 0xFF6B6B)
        static let aviso = dinamico(claro: 0xB45309, oscuro: 0xFFB340)
        static let neutro = dinamico(claro: 0x5B6475, oscuro: 0x9AA6BD)

        /// Capas: fondo < superficie < superficie elevada.
        static let fondo = dinamico(claro: 0xF4F6FA, oscuro: 0x0B1220)
        static let superficie = dinamico(claro: 0xFFFFFF, oscuro: 0x121B2E)
        static let superficieElevada = dinamico(claro: 0xEEF2F8, oscuro: 0x1A2540)
        static let borde = dinamico(claro: 0xE3E8F0, oscuro: 0x24304A)
        static let texto = dinamico(claro: 0x0B1220, oscuro: 0xF2F5FA)
        static let textoSecundario = dinamico(claro: 0x5B6475, oscuro: 0x9AA6BD)

        /// Tarjeta principal de cada pantalla (la cifra que más importa): azul marino en los dos
        /// modos. Su contenido se dibuja con los colores del modo oscuro (ver `TarjetaHero`).
        static let superficieHeroe = dinamico(claro: 0x0F1B33, oscuro: 0x16233F)
        static let bordeHeroe = dinamico(claro: 0x0F1B33, oscuro: 0x2A3A5E)

        /// Cabeceras que aún no se han pasado a `TarjetaHero`; desaparece al rediseñar cada pantalla.
        static let degradadoMarca = superficieHeroe

        /// Fondos de los iconos de sección (la pestaña Más): solo tonos de la marca.
        static let iconoAzul = fijo(0x1F5FE0)
        static let iconoMarino = fijo(0x2A3A5E)

        private static func dinamico(claro: UInt32, oscuro: UInt32) -> SwiftUI.Color {
            SwiftUI.Color(uiColor: UIColor { rasgos in
                UIColor(hex: rasgos.userInterfaceStyle == .dark ? oscuro : claro)
            })
        }

        private static func fijo(_ hex: UInt32) -> SwiftUI.Color {
            SwiftUI.Color(uiColor: UIColor(hex: hex))
        }
    }

    // MARK: Tipografía
    // SF Pro del sistema, con Dynamic Type. Cifras con dígitos de ancho fijo para que los
    // importes no "bailen" al cambiar ni desalineen las columnas.

    enum Fuente {
        /// La cifra protagonista de una pantalla (tarjeta principal).
        static let cifraHeroe = Font.system(.largeTitle, weight: .bold).monospacedDigit()
        static let cifraGrande = Font.system(.largeTitle, weight: .bold).monospacedDigit()
        static let cifra = Font.system(.title2, weight: .semibold).monospacedDigit()
        static let cifraMediana = Font.system(.title3, weight: .semibold).monospacedDigit()
        static let cifraPequena = Font.system(.headline, weight: .semibold).monospacedDigit()
        static let titulo = Font.title2.weight(.bold)
        static let tituloSeccion = Font.title3.weight(.semibold)
        static let subtitulo = Font.headline
        static let cuerpo = Font.body
        static let detalle = Font.subheadline
        static let etiqueta = Font.caption.weight(.semibold)
        static let nota = Font.caption
    }

    // MARK: Espaciado (escala fija 4 · 8 · 12 · 16 · 24 · 32)

    enum Espacio {
        /// Solo entre líneas de texto de un mismo bloque (título y subtítulo).
        static let linea: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: Radios

    enum Radio {
        static let pequeno: CGFloat = 8
        static let medio: CGFloat = 12
        static let grande: CGFloat = 16
        static let tarjeta: CGFloat = 20
    }

    // MARK: Tamaños fijos de iconos

    enum Tamano {
        /// Cuadrado de los iconos de fila y de KPI.
        static let icono: CGFloat = 32
        static let iconoPequeno: CGFloat = 28
        static let alturaBoton: CGFloat = 50
        static let alturaBarraProgreso: CGFloat = 6
    }

    // MARK: Movimiento

    enum Movimiento {
        static let suave = Animation.snappy(duration: 0.25)
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
            // Elevación: en claro una sombra mínima; en oscuro la da el borde y el cambio de capa.
            .shadow(color: .black.opacity(esquema == .dark ? 0 : 0.04), radius: 6, y: 1)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
