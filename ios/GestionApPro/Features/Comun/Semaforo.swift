import SwiftUI

/// Semáforo de la calificación de rentabilidad (verde / ámbar / rojo; gris sin datos).
extension Optional where Wrapped == Calificacion {
    var color: Color {
        switch self {
        case .excelente: .green
        case .aceptable: .orange
        case .aRevisar: .red
        case .desconocida, nil: .gray
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
}

struct SemaforoView: View {
    let calificacion: Calificacion?

    var body: some View {
        Circle()
            .fill(calificacion.color.gradient)
            .frame(width: 14, height: 14)
            .accessibilityLabel("Calificación: \(calificacion.texto)")
    }
}

/// Fila "etiqueta ........ valor" para las listas de métricas.
struct FilaDato: View {
    let titulo: String
    let valor: String
    var color: Color = .primary
    var nota: String? = nil

    var body: some View {
        LabeledContent {
            Text(valor)
                .monospacedDigit()
                .foregroundStyle(color)
        } label: {
            Text(titulo)
            if let nota {
                Text(nota).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

extension Decimal {
    /// Verde si es positivo, rojo si negativo.
    var colorSigno: Color {
        self < 0 ? .red : (self > 0 ? .green : .primary)
    }
}
