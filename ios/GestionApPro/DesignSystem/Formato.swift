import Foundation

/// Formatos en español de España: "2.500,00 €", "7,67 %".
///
/// El formato estándar de es_ES no pone punto en números de 4 cifras ("2500,00 €" junto a
/// "200.000,00 €"). En iOS 18+ se corrige con `minimumGroupingDigits = 1`; en iOS 17, donde
/// esa propiedad no existe, se usan las reglas numéricas de de_DE, que son idénticas a las
/// españolas (punto de miles, coma decimal, "€" detrás) salvo en que sí agrupan 4 cifras.
/// Solo afecta a los números: fechas y textos siguen en español. Ver FormatoTests.
enum Formato {
    static let locale = Locale(identifier: "es_ES")

    private static let moneda = formateador(.currency)
    private static let monedaSinDecimales = formateador(.currency, decimales: 0)
    private static let porcentajeFmt = formateador(.percent, decimales: 2, minimoDecimales: 2)

    /// Para campos de texto: agrupa miles al mostrar y admite "2.500,5" o "2500,5" al leer.
    static let numeroEditable: NumberFormatter = {
        let f = formateador(.decimal, decimales: 2)
        f.isLenient = true
        return f
    }()

    static func formateador(_ estilo: NumberFormatter.Style, decimales: Int? = nil, minimoDecimales: Int? = nil,
                            forzarRespaldoIOS17: Bool = false) -> NumberFormatter {
        let f = NumberFormatter()
        if #available(iOS 18.0, *), !forzarRespaldoIOS17 {
            f.locale = locale
            f.minimumGroupingDigits = 1
        } else {
            f.locale = Locale(identifier: "de_DE")
        }
        f.numberStyle = estilo
        if estilo == .currency { f.currencyCode = "EUR" }
        if let decimales { f.maximumFractionDigits = decimales }
        if let minimoDecimales { f.minimumFractionDigits = minimoDecimales }
        return f
    }

    static func euros(_ valor: Decimal) -> String {
        moneda.string(from: valor as NSDecimalNumber) ?? "—"
    }

    static func euros(_ valor: Decimal?) -> String {
        valor.map { euros($0) } ?? "—"
    }

    static func euros(_ valor: Double) -> String {
        moneda.string(from: NSNumber(value: valor)) ?? "—"
    }

    /// Sin céntimos, para ejes de gráficos y cifras redondas.
    static func eurosRedondo(_ valor: Double) -> String {
        monedaSinDecimales.string(from: NSNumber(value: valor)) ?? "—"
    }

    /// La API manda los porcentajes como 7.67 (no 0.0767).
    static func porcentaje(_ valor: Double?) -> String {
        guard let valor else { return "—" }
        return porcentajeFmt.string(from: NSNumber(value: valor / 100)) ?? "—"
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

    static func numero(_ valor: Int) -> String {
        numeroEditable.string(from: NSNumber(value: valor)) ?? "\(valor)"
    }
}

extension Decimal {
    var double: Double { NSDecimalNumber(decimal: self).doubleValue }
}
