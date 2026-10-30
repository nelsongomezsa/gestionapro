import Foundation

enum CategoriaGasto: String, Codable, CaseIterable, Identifiable, Sendable {
    case comunidad = "COMUNIDAD"
    case ibi = "IBI"
    case seguro = "SEGURO"
    case suministros = "SUMINISTROS"
    case reparacion = "REPARACION"
    case mantenimiento = "MANTENIMIENTO"
    case mobiliario = "MOBILIARIO"
    case intereses = "INTERESES"
    case gestion = "GESTION"
    case otros = "OTROS"

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .comunidad: "Comunidad"
        case .ibi: "IBI"
        case .seguro: "Seguro"
        case .suministros: "Suministros"
        case .reparacion: "Reparación"
        case .mantenimiento: "Mantenimiento"
        case .mobiliario: "Mobiliario"
        case .intereses: "Intereses de hipoteca"
        case .gestion: "Gestoría y administración"
        case .otros: "Otros"
        }
    }

    var icono: String {
        switch self {
        case .comunidad: "building.2"
        case .ibi: "building.columns"
        case .seguro: "shield"
        case .suministros: "bolt"
        case .reparacion: "wrench.and.screwdriver"
        case .mantenimiento: "paintbrush"
        case .mobiliario: "sofa"
        case .intereses: "percent"
        case .gestion: "briefcase"
        case .otros: "ellipsis.circle"
        }
    }
}

/// GET /api/gastos
struct Gasto: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let idPiso: Int
    let direccionPiso: String
    let idHabitacion: Int?
    let numeroHabitacion: Int?
    /// Viene de una incidencia resuelta con coste (su importe se cambia en la incidencia).
    let idIncidencia: Int?
    let categoria: CategoriaGasto
    let concepto: String
    let importe: Decimal
    let fecha: Date
    let deducible: Bool
    let tieneFactura: Bool
}

struct ResumenGastos: Decodable, Sendable {
    let lista: [Gasto]
    let total: Decimal
    let totalDeducible: Decimal
}

/// POST y PUT /api/gastos
struct GastoRequest: Encodable, Sendable {
    let idPiso: Int
    let idHabitacion: Int?
    let categoria: CategoriaGasto
    let concepto: String
    let importe: Decimal
    let fecha: String
    let deducible: Bool
}
