import Foundation

/// GET /api/estadisticas/analisis: estadísticas de un periodo (cartera, piso o habitación).
struct Analisis: Decodable, Sendable {
    let desde: Date
    let hasta: Date
    /// CARTERA, PISO o HABITACION
    let ambito: String
    let actual: Totales
    /// El mismo periodo un año antes.
    let anterior: Totales
    /// Ordenados por resultado neto: es el ranking.
    let pisos: [PisoAnalisis]
    let meses: [MesAnalisis]
    let morosidad: [Morosidad]

    struct Totales: Decodable, Hashable, Sendable {
        let ingresos: Decimal
        let gastos: Decimal
        let neto: Decimal
        let ocupacionPct: Double
        let diasMediosVacia: Double
        let habitaciones: Int
        let contratosIniciados: Int
        let contratosFinalizados: Int
        let duracionMediaMeses: Double?
        let rotacionPct: Double
        let impagado: Decimal
    }

    struct PisoAnalisis: Decodable, Identifiable, Hashable, Sendable {
        let piso: PisoBreve
        let ingresos: Decimal
        let gastos: Decimal
        let neto: Decimal
        let ocupacionPct: Double
        let diasMediosVacia: Double
        let habitaciones: Int
        var id: Int { piso.id }
    }

    struct MesAnalisis: Decodable, Identifiable, Hashable, Sendable {
        let mes: String
        let etiqueta: String
        let ingresos: Decimal
        let gastos: Decimal
        /// nil en los meses que aún no han empezado.
        let ocupacionPct: Double?
        var id: String { mes }
    }

    struct Morosidad: Decodable, Identifiable, Hashable, Sendable {
        let idInquilino: Int
        let nombre: String
        let mesesDebidos: Int
        let mesesImpagados: Int
        let pagosFueraDePlazo: Int
        let importeImpagado: Decimal
        let puntualidadPct: Double
        var id: Int { idInquilino }
    }
}

/// Variación en % de un valor frente al del año anterior; nil si entonces era 0.
func variacionPct(_ actual: Decimal, _ anterior: Decimal) -> Double? {
    guard anterior != 0 else { return nil }
    return ((actual - anterior) / abs(anterior)).double * 100
}
