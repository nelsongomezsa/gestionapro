import Foundation

/// Formatos en español de España: "1.234,56 €" y "7,67 %".
enum Formato {
    static let locale = Locale(identifier: "es_ES")

    static func euros(_ valor: Decimal) -> String {
        valor.formatted(.currency(code: "EUR").locale(locale))
    }

    static func euros(_ valor: Decimal?) -> String {
        valor.map { euros($0) } ?? "—"
    }

    /// La API manda los porcentajes como 7.67 (no 0.0767).
    static func porcentaje(_ valor: Double?) -> String {
        guard let valor else { return "—" }
        return (valor / 100).formatted(.percent.precision(.fractionLength(2)).locale(locale))
    }

    static func porcentaje(_ valor: Decimal?) -> String {
        porcentaje(valor.map { NSDecimalNumber(decimal: $0).doubleValue })
    }

    static func anios(_ valor: Double?) -> String {
        guard let valor else { return "—" }
        return valor.formatted(.number.precision(.fractionLength(1)).locale(locale)) + " años"
    }

    static func anios(_ valor: Decimal?) -> String {
        anios(valor.map { NSDecimalNumber(decimal: $0).doubleValue })
    }
}
