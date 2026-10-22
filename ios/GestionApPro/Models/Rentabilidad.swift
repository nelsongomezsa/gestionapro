import Foundation

/// POST /api/calculadora/rentabilidad. Importes mensuales salvo que el nombre diga otra cosa.
struct RentabilidadRequest: Encodable, Equatable, Sendable {
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
