import SwiftUI

/// Una pestaña de la barra propia.
struct ItemPestana: Identifiable {
    let pestana: Pestana
    let titulo: LocalizedStringKey
    let nombre: String
    let icono: String
    var globo = 0
    var id: Pestana { pestana }
}

/// Barra de pestañas de Liquid Glass con el botón «+» separado a la derecha, en la misma fila (como
/// la lupa de las apps de Apple en iOS 26). La del sistema no admite cinco pestañas y un botón aparte.
struct BarraPestanas: View {
    static let alto: CGFloat = 62

    let items: [ItemPestana]
    @Binding var seleccion: Pestana
    let repetir: (Pestana) -> Void
    let crear: () -> Void
    @Namespace private var marca
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        GlassEffectContainer(spacing: Tema.Espacio.s) {
            HStack(spacing: Tema.Espacio.s) {
                HStack(spacing: 0) {
                    ForEach(items) { item in boton(item) }
                }
                .padding(4)
                .frame(height: Self.alto)
                .fondoCristal(en: .capsule, interactivo: false)

                Button(action: crear) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Tema.Color.texto)
                        .frame(width: Self.alto, height: Self.alto)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .fondoCristal(en: .circle)
                .accessibilityLabel("Crear")
                .accessibilityHint("Cobro, incidencia, gasto o mensaje")
                .accessibilityIdentifier("botonCrear")
            }
        }
        .padding(.horizontal, Tema.Espacio.m)
        .padding(.bottom, 2)
    }

    private func boton(_ item: ItemPestana) -> some View {
        let activa = item.pestana == seleccion
        return Button {
            if activa { repetir(item.pestana) } else {
                withAnimation(reducirMovimiento ? nil : Tema.Movimiento.suave) { seleccion = item.pestana }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: item.icono)
                    .font(.system(size: 19, weight: activa ? .semibold : .regular))
                    .symbolVariant(activa ? .fill : .none)
                    .frame(height: 24)
                    .overlay(alignment: .topTrailing) {
                        if item.globo > 0 {
                            Text(item.globo > 99 ? "99+" : "\(item.globo)")
                                .font(.caption2.weight(.bold)).monospacedDigit()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Tema.Color.negativo, in: .capsule)
                                .offset(x: 12, y: -6)
                        }
                    }
                Text(item.titulo)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(activa ? Tema.Color.primario : Tema.Color.texto)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if activa {
                    Capsule().fill(Tema.Color.primario.opacity(0.14))
                        .matchedGeometryEffect(id: "marca", in: marca)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.globo > 0 ? Text("\(Text(item.titulo)), \(item.globo) sin leer") : Text(item.titulo))
        .accessibilityAddTraits(activa ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("pestana:\(item.nombre)")
    }
}
