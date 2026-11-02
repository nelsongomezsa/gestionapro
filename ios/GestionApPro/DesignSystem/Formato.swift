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

    /// Fechas y nombres de mes en el idioma en que se ve la app (español o inglés), con las
    /// convenciones de España: "noviembre 2026" o "November 2026". Importes y cifras siguen con `locale`.
    static let localeFechas: Locale = {
        let idioma = Bundle.main.preferredLocalizations.first ?? "es"
        return Locale(identifier: idioma.hasPrefix("en") ? "en_ES" : "es_ES")
    }()

    /// Para mitad de frase ("Cobrado en noviembre 2026" / "Collected in November 2026").
    static func mesEnFrase(_ aaaamm: String, en locale: Locale = localeFechas) -> String? {
        guard let m = mes(aaaamm, en: locale) else { return nil }
        return locale.language.languageCode?.identifier == "en" ? m : m.prefix(1).lowercased() + m.dropFirst()
    }

    /// "2026-10" → "Octubre 2026" (o "October 2026"); con `corto`, "oct" (u "Oct").
    /// La API manda los meses en español: la app los formatea con su idioma a partir del aaaa-mm.
    static func mes(_ aaaamm: String, corto: Bool = false, en locale: Locale = localeFechas) -> String? {
        let partes = aaaamm.split(separator: "-").compactMap { Int($0) }
        guard partes.count >= 2, (1...12).contains(partes[1]) else { return nil }
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        if corto {
            let s = c.shortStandaloneMonthSymbols[partes[1] - 1].replacingOccurrences(of: ".", with: "")
            return locale.language.languageCode?.identifier == "en" ? s : s.lowercased()
        }
        let s = c.standaloneMonthSymbols[partes[1] - 1]
        return s.prefix(1).uppercased() + s.dropFirst() + " \(partes[0])"
    }

    private static let moneda = formateador(.currency)
    private static let monedaSinDecimales = formateador(.currency, decimales: 0)
    private static let porcentajeFmt = formateador(.percent, decimales: 2, minimoDecimales: 2)

    /// Para campos de texto: agrupa miles al mostrar y admite "2.500,5" o "2500,5" al leer.
    static let numeroEditable: NumberFormatter = {
        let f = formateador(.decimal, decimales: 2)
        f.isLenient = true
        return f
    }()

    static func formateador(_ estilo: NumberFormatter.Style, decimales: Int? = nil, minimoDecimales: Int? = nil) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = locale
        // El español no agrupa los miles de 4 cifras por defecto ("2500 €"); la app usa "2.500 €".
        f.minimumGroupingDigits = 1
        f.numberStyle = estilo
        if estilo == .currency { f.currencyCode = "EUR" }
        if let decimales { f.maximumFractionDigits = decimales }
        if let minimoDecimales { f.minimumFractionDigits = minimoDecimales }
        // Redondeo comercial (1,625 → 1,63), como el HALF_UP de la API; por defecto sería el bancario.
        f.roundingMode = .halfUp
        return f
    }

    /// "jueves, 1 de octubre" -> "Jueves, 1 de octubre" (capitalized pondría "De" y "Octubre").
    static func primeraMayuscula(_ texto: String) -> String {
        texto.prefix(1).uppercased(with: locale) + texto.dropFirst()
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
        guard let valor, valor.isFinite else { return "—" }
        // En Decimal: 1.625 / 100 en Double ya no es exacto y redondearía hacia abajo.
        return porcentajeFmt.string(from: NSDecimalNumber(decimal: Decimal(valor) / 100)) ?? "—"
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

    /// "12,5": una cifra decimal (días medios, meses).
    static func numero(_ valor: Double) -> String {
        valor.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    }

    static func numero(_ valor: Int) -> String {
        numeroEditable.string(from: NSNumber(value: valor)) ?? "\(valor)"
    }
}

extension Decimal {
    var double: Double { NSDecimalNumber(decimal: self).doubleValue }
}
