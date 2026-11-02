import Foundation

/// POST /api/calculadora/rentabilidad. Importes mensuales salvo que el nombre diga otra cosa.
struct RentabilidadRequest: Codable, Equatable, Hashable, Sendable {
    var comunidad: String
    var precioCompra: Double
    var gastosNotariaRegistro: Double
    var gastosHipoteca: Double
    var reforma: Double
    var comisionCompra: Double
    var mobiliario: Double
    var ibiMensual: Double
    var segurosMensual: Double
    var comunidadMensual: Double
    var mantenimientoMensual: Double
    var vacioMensual: Double
    var alquilerMensual: Double
    var revalorizacionAnualPct: Double
    var porcentajeFinanciado: Double
    var plazoAnos: Int
    var tipoInteresPct: Double
}

extension RentabilidadRequest {
    /// Los opcionales que falten cuentan como 0 (como en la API).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func n(_ k: CodingKeys) throws -> Double { try c.decodeIfPresent(Double.self, forKey: k) ?? 0 }
        self.init(comunidad: try c.decode(String.self, forKey: .comunidad), precioCompra: try n(.precioCompra),
                  gastosNotariaRegistro: try n(.gastosNotariaRegistro), gastosHipoteca: try n(.gastosHipoteca),
                  reforma: try n(.reforma), comisionCompra: try n(.comisionCompra), mobiliario: try n(.mobiliario),
                  ibiMensual: try n(.ibiMensual), segurosMensual: try n(.segurosMensual),
                  comunidadMensual: try n(.comunidadMensual), mantenimientoMensual: try n(.mantenimientoMensual),
                  vacioMensual: try n(.vacioMensual), alquilerMensual: try n(.alquilerMensual),
                  revalorizacionAnualPct: try n(.revalorizacionAnualPct), porcentajeFinanciado: try n(.porcentajeFinanciado),
                  plazoAnos: try c.decodeIfPresent(Int.self, forKey: .plazoAnos) ?? 0, tipoInteresPct: try n(.tipoInteresPct))
    }
}

/// GET /api/analisis-inversion: una simulación guardada con nombre; el resultado lo recalcula la API.
struct AnalisisGuardado: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let nombre: String
    let idPiso: Int?
    let fecha: Date
    let entrada: RentabilidadRequest
    /// nil si ya no se puede calcular (p. ej., comunidad retirada de la tabla de ITP).
    let resultado: RentabilidadResponse?
}

/// POST y PUT /api/analisis-inversion
struct AnalisisGuardadoRequest: Encodable, Sendable {
    let nombre: String
    let idPiso: Int?
    let entrada: RentabilidadRequest
}

/// Respuesta de la calculadora: importes y % ya redondeados a 2 decimales por la API.
struct RentabilidadResponse: Decodable, Hashable, Sendable {
    let itpPct: Decimal
    let itpImporte: Decimal
    let totalCompra: Decimal
    let gastosMensuales: Decimal
    let gastosAnuales: Decimal
    let alquilerAnual: Decimal
    let hipoteca: Decimal
    let capitalAportado: Decimal
    let cuotaMensual: Decimal
    let interesesMensualesPromedio: Decimal
    let amortizacionMensualPromedio: Decimal
    let rentabilidadBrutaPct: Decimal
    let rentabilidadNetaPct: Decimal
    let cashFlowMensual: Decimal
    let cashFlowAnual: Decimal
    /// nil si el cash flow no es positivo.
    let aniosRecuperacion: Decimal?
    /// nil si no hay revalorización.
    let plusvalia5Anios: Decimal?
    let plusvalia10Anios: Decimal?
}

/// GET /api/calculadora/itp
struct ItpResponse: Decodable, Equatable, Sendable {
    let anioReferencia: String?
    let comunidades: [Comunidad]

    struct Comunidad: Decodable, Equatable, Hashable, Sendable {
        let nombre: String
        let tipoPct: Double
    }
}
