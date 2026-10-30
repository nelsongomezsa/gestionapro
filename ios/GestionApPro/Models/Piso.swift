import Foundation

/// GET /api/pisos y /api/pisos/{id}. Los importes son Decimal: llegan como números JSON exactos.
struct Piso: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let direccion: String
    let ciudad: Ciudad
    let numeroHabitaciones: Int
    let idPropietario: Int
    let ocupacion: Ocupacion
    /// Suma de las rentas de los contratos activos hoy.
    let ingresosMensuales: Decimal
    /// nil si el piso no tiene datos financieros (y entonces tampoco métricas).
    let datosFinancieros: DatosFinancieros?
    let metricas: Metricas?

    struct Ciudad: Decodable, Equatable, Sendable {
        let id: Int
        let nombre: String
    }

    struct Ocupacion: Decodable, Equatable, Sendable {
        let total: Int
        let alquiladas: Int
        let disponibles: Int
        let mantenimiento: Int
    }

    /// Salida de CalculadoraFinancieraPiso en la API. Los % vienen como 7.67 (no 0.0767)
    /// y faltan cuando no son calculables.
    struct Metricas: Decodable, Equatable, Sendable {
        let inversionTotal: Decimal
        let cuotaMensualHipoteca: Decimal
        let gastosAnuales: Decimal
        let rentabilidadBrutaPct: Double?
        let rentabilidadNetaPct: Double?
        let calificacion: Calificacion?
        let cashFlowMensual: Decimal
        /// Cash flow anual / capital propio. En el escritorio se llamaba "ROCE".
        let cashOnCashPct: Double?
        let capitalPropio: Decimal
        let plusvaliaLatente: Decimal
        let perAnios: Double?
    }

    struct DatosFinancieros: Decodable, Equatable, Sendable {
        let precioCompra: Decimal?
        let itpPagado: Decimal?
        let gastosNotaria: Decimal?
        let gastosRegistro: Decimal?
        let costeReforma: Decimal?
        let costeMobiliario: Decimal?
        let otrosGastosCompra: Decimal?
        let tieneHipoteca: Bool
        let importeHipoteca: Decimal?
        let tipoInteres: Decimal?
        let plazoAnos: Int?
        let cuotaMensualHipoteca: Decimal?
        let gastoIbiAnual: Decimal?
        let gastoComunidadMensual: Decimal?
        let gastoSeguroAnual: Decimal?
        let gastoMantenimientoAnual: Decimal?
        let valorMercadoActual: Decimal?
        let fechaCompra: Date?
        let notas: String?
    }
}

/// Semáforo de rentabilidad bruta (umbrales del escritorio: > 7 % excelente, ≥ 5 % aceptable).
enum Calificacion: String, Decodable, Sendable {
    case excelente = "EXCELENTE"
    case aceptable = "ACEPTABLE"
    case aRevisar = "A_REVISAR"
    case desconocida

    init(from decoder: Decoder) throws {
        let valor = try decoder.singleValueContainer().decode(String.self)
        self = Calificacion(rawValue: valor) ?? .desconocida
    }
}

extension Piso {
    var breve: PisoBreve { PisoBreve(id: id, direccion: direccion, ciudad: ciudad.nombre) }
}
