import SwiftUI

/// Lengüeta del asistente: una pestaña de cristal con destellos pegada al borde derecho, en todas las pestañas.
/// Se abre tocándola o tirando de ella hacia la izquierda; arrastrándola en vertical se mueve por el
/// borde (la posición se guarda). Se puede ocultar en Ajustes.
struct LenguetaAsistente: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @AppStorage(Preferencias.lengueta) private var visible = true
    /// Posición vertical como fracción del alto disponible (0 arriba, 1 abajo).
    @AppStorage(Preferencias.lenguetaPosicion) private var posicion = 0.42
    let abrir: () -> Void
    @State private var desplazamiento: CGFloat = 0

    /// Lo justo para quedarse en el margen lateral de la página (16 pt) sin tapar las tarjetas.
    static let anchoVisible: CGFloat = 16
    static let altoVisible: CGFloat = 64

    var body: some View {
        GeometryReader { geo in
            if visible {
                let alto = geo.size.height
                let y = min(max(alto * posicion + desplazamiento, 90), alto - 90)
                let forma = UnevenRoundedRectangle(topLeadingRadius: 9, bottomLeadingRadius: 9,
                                                   bottomTrailingRadius: 0, topTrailingRadius: 0)
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Tema.Color.primario)
                    .frame(width: Self.anchoVisible, height: Self.altoVisible)
                    .fondoCristal(en: forma, interactivo: false)
                    // Borde fino: se distingue del fondo tanto en claro como en oscuro.
                    .overlay(forma.stroke(Tema.Color.primario.opacity(0.35), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 6, x: -1, y: 2)
                    // Zona táctil mucho más grande que lo que se ve (44 pt de ancho como mínimo).
                    .frame(width: 44, height: Self.altoVisible + 24, alignment: .trailing)
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
                    .position(x: geo.size.width - 22, y: y)
                    // La pastilla se pega al borde: el centro de la zona táctil queda a 22 pt.
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
