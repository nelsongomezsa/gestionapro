import Foundation

/// GET /api/pisos/{id}/resumen-fiscal (orientativo)
struct ResumenFiscal: Decodable, Sendable {
    struct Linea: Decodable, Hashable, Sendable {
        let concepto: String
        let importe: Decimal
    }

    let anio: Int
    let piso: String
    let ingresos: Decimal
    let numeroPagos: Int
    let gastosConLimite: [Linea]
    let gastosConLimiteAplicables: Decimal
    let excesoParaAniosSiguientes: Decimal
    let otrosGastos: [Linea]
    /// nil si faltan los valores catastrales o los datos de compra (baseAmortizacion lo explica).
    let amortizacionInmueble: Decimal?
    let baseAmortizacion: String
    let amortizacionMobiliario: Decimal
    let rendimientoNeto: Decimal
    let notas: [String]
}
