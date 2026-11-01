import SwiftUI
import UIKit

/// Respuesta háptica para lo que importa (registrar, borrar, fallar). Sigue los ajustes de vibración
/// del sistema. Se usa justo antes de cerrar una hoja, cuando `.sensoryFeedback` de la
/// vista ya no llegaría a sonar.
@MainActor
enum Haptica {
    /// Se puede desactivar en Ajustes › Vibración.
    private static var activa: Bool { Preferencias.activado(Preferencias.vibracion) }
    static func exito() { if activa { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    static func error() { if activa { UINotificationFeedbackGenerator().notificationOccurred(.error) } }
    static func impacto() { if activa { UIImpactFeedbackGenerator(style: .medium).impactOccurred() } }
    static func suave() { if activa { UIImpactFeedbackGenerator(style: .soft).impactOccurred() } }
}

/// Aparición escalonada y breve de las tarjetas de una pantalla. Con Reducir movimiento, sin desplazamiento.
private struct Aparicion: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    let indice: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reducirMovimiento ? 0 : 12)
            .onAppear {
                guard !visible else { return }
                if reducirMovimiento { visible = true; return }
                withAnimation(Tema.Movimiento.entrada.delay(Double(min(indice, 6)) * 0.05)) { visible = true }
            }
    }
}

extension View {
    func aparicion(_ indice: Int) -> some View { modifier(Aparicion(indice: indice)) }
}

/// Esqueleto de carga: la forma de una pantalla (cifra principal, tarjetas y filas) en lugar de una rueda.
/// Late suavemente; con Reducir movimiento se queda quieto.
struct EsqueletoCarga: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var tenue = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.l) {
            bloque(alto: 150, radio: Tema.Radio.grande)
            HStack(spacing: Tema.Espacio.s) {
                bloque(alto: 100, radio: Tema.Radio.grande)
                bloque(alto: 100, radio: Tema.Radio.grande)
            }
            VStack(spacing: Tema.Espacio.s) {
                ForEach(0..<4, id: \.self) { _ in bloque(alto: 56, radio: Tema.Radio.medio) }
            }
            Spacer(minLength: 0)
        }
        .padding(Tema.Espacio.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(tenue ? 0.45 : 1)
        .onAppear {
            guard !reducirMovimiento else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { tenue = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cargando")
    }

    private func bloque(alto: CGFloat, radio: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radio).fill(Tema.Color.superficieElevada).frame(maxWidth: .infinity).frame(height: alto)
    }
}
