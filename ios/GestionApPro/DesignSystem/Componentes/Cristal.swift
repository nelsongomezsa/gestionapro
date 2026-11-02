import SwiftUI

/// Fondo de Liquid Glass para controles que flotan sobre el contenido (botones flotantes, burbuja
/// del asistente). Con Reducir transparencia pasa a una superficie sólida con borde, del mismo tamaño.
struct FondoCristal<Forma: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reducirTransparencia
    let forma: Forma
    var interactivo = true

    func body(content: Content) -> some View {
        if reducirTransparencia {
            content
                .background(Tema.Color.superficie, in: forma)
                .overlay(forma.stroke(Tema.Color.borde, lineWidth: 1))
        } else {
            content.glassEffect(.regular.tint(Tema.Cristal.tinte).interactive(interactivo), in: forma)
        }
    }
}

extension View {
    func fondoCristal<Forma: Shape>(en forma: Forma, interactivo: Bool = true) -> some View {
        modifier(FondoCristal(forma: forma, interactivo: interactivo))
    }
}
