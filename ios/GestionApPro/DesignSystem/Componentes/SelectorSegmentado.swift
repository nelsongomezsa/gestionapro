import SwiftUI

/// Filtro de píldoras (sustituye al Picker segmentado, que cortaba etiquetas con contador
/// como "Pendiente (5)"). Si no caben, se desplazan en horizontal; nunca se recortan.
struct SelectorSegmentado<Valor: Hashable>: View {
    let opciones: [(valor: Valor, titulo: String)]
    @Binding var seleccion: Valor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tema.Espacio.xs) {
                ForEach(opciones, id: \.valor) { o in
                    let elegido = o.valor == seleccion
                    Button {
                        withAnimation(Tema.Movimiento.suave) { seleccion = o.valor }
                    } label: {
                        Text(o.titulo)
                            .font(Tema.Fuente.detalle.weight(.semibold))
                            .foregroundStyle(elegido ? Tema.Color.sobrePrimario : Tema.Color.texto)
                            .padding(.horizontal, Tema.Espacio.m)
                            .frame(minHeight: Tema.Tamano.botonRedondo * 0.8)
                            .background(elegido ? Tema.Color.primarioRelleno : Tema.Color.superficie, in: .capsule)
                            .overlay(Capsule().strokeBorder(elegido ? .clear : Tema.Color.borde, lineWidth: 1))
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(elegido ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }
}
