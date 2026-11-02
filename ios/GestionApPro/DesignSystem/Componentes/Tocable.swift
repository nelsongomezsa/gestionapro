import SwiftUI

/// Pulsación de una tarjeta tocable: se hunde un poco al tocarla. Con Reducir movimiento
/// no cambia de tamaño, solo se atenúa.
struct EstiloPulsable: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reducirMovimiento ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Tema.Movimiento.suave, value: configuration.isPressed)
    }
}

/// Resumen que se puede tocar (tarjeta de Inicio, alerta, métrica...): chevron discreto arriba
/// a la derecha, efecto de pulsación, vibración ligera, rasgo de botón y pista de VoiceOver.
struct TarjetaTocable<Contenido: View>: View {
    /// Lo que dice VoiceOver tras la etiqueta ("Abre la ocupación de cada piso").
    let pista: String
    var mostrarChevron = true
    let accion: () -> Void
    @ViewBuilder var contenido: Contenido

    var body: some View {
        Button {
            Haptica.ligera()
            accion()
        } label: {
            contenido
                .overlay(alignment: .topTrailing) {
                    if mostrarChevron { ChevronTocable().padding(Tema.Espacio.m) }
                }
                .contentShape(.rect)
        }
        .buttonStyle(EstiloPulsable())
        .accessibilityHint(Text(LocalizedStringKey(pista)))
    }
}

/// Chevron pequeño y tenue que indica que algo se abre.
struct ChevronTocable: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(Tema.Fuente.nota.weight(.semibold))
            .foregroundStyle(Tema.Color.textoSecundario.opacity(0.7))
            .accessibilityHidden(true)
    }
}

extension View {
    /// Destino de una transición de zoom desde `origenZoom`. Con Reducir movimiento,
    /// la transición normal del sistema (sin zoom).
    func destinoZoom<ID: Hashable>(_ id: ID, en espacio: Namespace.ID) -> some View {
        modifier(DestinoZoom(id: id, espacio: espacio))
    }
}

private struct DestinoZoom<ID: Hashable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    let id: ID
    let espacio: Namespace.ID

    func body(content: Content) -> some View {
        if reducirMovimiento {
            content.navigationTransition(.automatic)
        } else {
            content.navigationTransition(.zoom(sourceID: id, in: espacio))
        }
    }
}
