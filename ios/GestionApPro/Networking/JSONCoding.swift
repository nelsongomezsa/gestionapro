import Foundation

enum JSONCoding {
    /// La API manda tres formatos de fecha: Instant con fracción de segundo y "Z"
    /// (expira del token), LocalDate "2020-11-08" (fechaCompra) y LocalDateTime sin
    /// zona (expira de una invitación, hora de Madrid). El .iso8601 de JSONDecoder no
    /// acepta fracciones de segundo, así que se prueban en orden.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let texto = try d.singleValueContainer().decode(String.self)
            if let fecha = fecha(texto) { return fecha }
            throw DecodingError.dataCorrupted(.init(codingPath: d.codingPath,
                                                    debugDescription: "Fecha no reconocida: \(texto)"))
        }
        return decoder
    }

    static func encoder() -> JSONEncoder {
        JSONEncoder()
    }

    private static let madrid = TimeZone(identifier: "Europe/Madrid")!

    static func fecha(_ texto: String) -> Date? {
        let conZona = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let conZonaSinFraccion = Date.ISO8601FormatStyle()
        if let f = try? conZona.parse(texto) { return f }
        if let f = try? conZonaSinFraccion.parse(texto) { return f }
        if let f = try? Date.ISO8601FormatStyle(timeZone: madrid).year().month().day()
            .dateSeparator(.dash).parse(texto) { return f }
        // LocalDateTime: se recorta la fracción de segundo y se interpreta en hora de Madrid.
        let sinFraccion = texto.split(separator: ".").first.map(String.init) ?? texto
        return try? Date.ISO8601FormatStyle(timeZone: madrid)
            .year().month().day().dateSeparator(.dash)
            .dateTimeSeparator(.standard)
            .time(includingFractionalSeconds: false).timeSeparator(.colon)
            .parse(sinFraccion)
    }
}
