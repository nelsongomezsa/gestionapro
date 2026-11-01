import SwiftUI

/// Lengüeta del asistente: una línea fina de cristal pegada al borde derecho, en todas las pestañas.
/// Se abre tocándola o tirando de ella hacia la izquierda; arrastrándola en vertical se mueve por el
/// borde (la posición se guarda). Se puede ocultar en Ajustes.
struct LenguetaAsistente: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @AppStorage(Preferencias.lengueta) private var visible = true
    /// Posición vertical como fracción del alto disponible (0 arriba, 1 abajo).
    @AppStorage(Preferencias.lenguetaPosicion) private var posicion = 0.42
    let abrir: () -> Void
    @State private var desplazamiento: CGFloat = 0

    static let anchoVisible: CGFloat = 7
    static let altoVisible: CGFloat = 72

    var body: some View {
        GeometryReader { geo in
            if visible {
                let alto = geo.size.height
                let y = min(max(alto * posicion + desplazamiento, 90), alto - 90)
                Capsule()
                    .fill(.clear)
                    .frame(width: Self.anchoVisible, height: Self.altoVisible)
                    .fondoCristal(en: Capsule(), interactivo: false)
                    .overlay(Capsule().fill(Tema.Color.primario.opacity(0.55)).frame(width: 3, height: 28))
                    // Zona táctil mucho más grande que lo que se ve (44 pt de ancho como mínimo).
                    .frame(width: 30, height: Self.altoVisible + 24, alignment: .trailing)
                    .contentShape(.rect)
                    .onTapGesture { abrir() }
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { g in
                                // Vertical: se mueve; horizontal hacia dentro: se abre al soltar.
                                if abs(g.translation.height) > abs(g.translation.width) {
                                    if reducirMovimiento { return }
                                    desplazamiento = g.translation.height
                                }
                            }
                            .onEnded { g in
                                if g.translation.width < -24 && abs(g.translation.width) > abs(g.translation.height) {
                                    abrir()
                                } else if abs(g.translation.height) > 8 {
                                    posicion = min(max((alto * posicion + g.translation.height) / alto, 0.15), 0.85)
                                }
                                desplazamiento = 0
                            }
                    )
                    .position(x: geo.size.width - 15, y: y)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Asistente")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Abre el asistente sobre lo que tienes en pantalla")
                    .accessibilityAction { abrir() }
                    .accessibilityAction(named: "Abrir") { abrir() }
                    .accessibilityIdentifier("lenguetaAsistente")
                    .transition(.opacity)
            }
        }
    }
}
