import SwiftUI

/// Píldora de estado: "Alquilada", "Crítico", "Excelente"...
struct InsigniaEstado: View {
    let texto: String
    var tono: Tono = .neutro
    var icono: String? = nil

    var body: some View {
        HStack(spacing: Tema.Espacio.xxs) {
            if let icono { Image(systemName: icono).imageScale(.small) }
            Text(texto)
        }
        .font(Tema.Fuente.etiqueta)
        .foregroundStyle(tono.color)
        .padding(.horizontal, Tema.Espacio.xs)
        .padding(.vertical, Tema.Espacio.xxs)
        .background(tono.color.opacity(0.14), in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

extension Calificacion? {
    /// Semáforo de rentabilidad (umbrales del escritorio: > 7 % excelente, ≥ 5 % aceptable).
    var tono: Tono {
        switch self {
        case .excelente: .positivo
        case .aceptable: .aviso
        case .aRevisar: .negativo
        case .desconocida, nil: .neutro
        }
    }

    var texto: String {
        switch self {
        case .excelente: "Excelente"
        case .aceptable: "Aceptable"
        case .aRevisar: "A revisar"
        case .desconocida: "Sin calificar"
        case nil: "Sin datos"
        }
    }

    var icono: String {
        switch self {
        case .excelente: "arrow.up.right"
        case .aceptable: "equal"
        case .aRevisar: "arrow.down.right"
        case .desconocida, nil: "questionmark"
        }
    }

    var insignia: InsigniaEstado { InsigniaEstado(texto: texto, tono: tono, icono: icono) }
}

#Preview {
    VStack(alignment: .leading) {
        Calificacion?.some(.excelente).insignia
        Calificacion?.some(.aceptable).insignia
        Calificacion?.some(.aRevisar).insignia
        Calificacion?.none.insignia
    }
    .padding()
}
