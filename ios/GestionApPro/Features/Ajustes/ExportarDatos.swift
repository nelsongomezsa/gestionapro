import Foundation

/// Exportar mis datos: CSV (separado por punto y coma, como lo abre Excel en español) de pisos,
/// cobros y gastos. Solo con lo que el usuario ya puede ver por la API.
enum ExportarDatos {
    static func csvPisos(_ pisos: [Piso]) -> String {
        filas(["Dirección", "Ciudad", "Tipo", "Unidades"],
              pisos.map { [$0.direccion, $0.ciudad.nombre, $0.tipoInmueble.rawValue, "\($0.numeroHabitaciones)"] })
    }

    static func csvCobros(_ pagos: [Pago]) -> String {
        filas(["Fecha", "Inquilino", "Inmueble", "Unidad", "Importe", "Método", "Recibo"],
              pagos.map { [FechaAPI.texto($0.fechaPago), $0.inquilino.nombre, $0.piso.direccion, $0.etiquetaUnidad,
                           importe($0.cantidad), $0.metodoPago.nombre, $0.recibo ?? ""] })
    }

    static func csvGastos(_ gastos: [Gasto]) -> String {
        filas(["Fecha", "Inmueble", "Categoría", "Concepto", "Importe", "Deducible"],
              gastos.map { [FechaAPI.texto($0.fecha), $0.direccionPiso, $0.categoria.nombre, $0.concepto,
                            importe($0.importe), $0.deducible ? "Sí" : "No"] })
    }

    /// Escribe los tres archivos en una carpeta temporal y devuelve sus URL para compartirlos.
    static func escribir(pisos: [Piso], pagos: [Pago], gastos: [Gasto]) throws -> [URL] {
        let carpeta = FileManager.default.temporaryDirectory.appendingPathComponent("GestionAp-exportacion", isDirectory: true)
        try? FileManager.default.removeItem(at: carpeta)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let archivos = [("inmuebles.csv", csvPisos(pisos)), ("cobros.csv", csvCobros(pagos)), ("gastos.csv", csvGastos(gastos))]
        return try archivos.map { nombre, texto in
            let url = carpeta.appendingPathComponent(nombre)
            // BOM: Excel reconoce así los acentos.
            try Data(("\u{FEFF}" + texto).utf8).write(to: url, options: .completeFileProtection)
            return url
        }
    }

    private static func importe(_ d: Decimal) -> String {
        NSDecimalNumber(decimal: d).stringValue.replacingOccurrences(of: ".", with: ",")
    }

    static func filas(_ cabecera: [String], _ datos: [[String]]) -> String {
        ([cabecera] + datos).map { $0.map(campo).joined(separator: ";") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Entre comillas si lleva separador, comillas o saltos; y sin fórmulas (un campo que empieza por
    /// = + - @ se abriría como fórmula en una hoja de cálculo).
    static func campo(_ s: String) -> String {
        var v = s
        let controlInicial = v.first == "\t" || v.first == "\r"
        let primeroSignificativo = v.first(where: { ![" ", "\t", "\r", "\n"].contains($0) })
        if controlInicial || (primeroSignificativo.map { "=+-@".contains($0) } ?? false) { v = "'" + v }
        if v.contains(";") || v.contains("\"") || v.contains("\n") || v.contains("\r") {
            v = "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return v
    }
}
