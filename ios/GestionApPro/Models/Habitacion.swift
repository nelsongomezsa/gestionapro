import Foundation

/// GET /api/habitaciones
struct Habitacion: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let numero: Int
    let precio: Decimal
    let estado: EstadoHabitacion
    let piso: PisoBreve
    /// Inquilino del contrato activo hoy; nil si no hay.
    let inquilinoActual: InquilinoActual?
    let idContratoActivo: Int?
    let diasAlquilada: Int?

    struct InquilinoActual: Decodable, Hashable, Sendable {
        let id: Int
        let nombre: String
    }
}

struct PisoBreve: Codable, Hashable, Sendable {
    let id: Int
    let direccion: String
    let ciudad: String
}

enum EstadoHabitacion: String, Codable, CaseIterable, Identifiable, Sendable {
    case disponible, alquilada, mantenimiento

    var id: Self { self }

    var nombre: String {
        switch self {
        case .disponible: "Disponible"
        case .alquilada: "Alquilada"
        case .mantenimiento: "Mantenimiento"
        }
    }

    var icono: String {
        switch self {
        case .disponible: "door.left.hand.open"
        case .alquilada: "key.fill"
        case .mantenimiento: "wrench.and.screwdriver"
        }
    }

    var tono: Tono {
        switch self {
        case .disponible: .primario
        case .alquilada: .positivo
        case .mantenimiento: .aviso
        }
    }
}

/// POST y PUT /api/habitaciones
struct HabitacionRequest: Encodable, Sendable {
    var idPiso: Int
    var numero: Int
    var precio: Decimal
    var estado: EstadoHabitacion
}

struct CambioEstadoRequest: Encodable, Sendable {
    let estado: EstadoHabitacion
}
