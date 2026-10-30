import Foundation

/// GET /api/incidencias/{id}/fotos
struct FotoIncidencia: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let fecha: Date
    let tipo: String
    /// La subió quien mira (el inquilino solo puede borrar las suyas).
    let mia: Bool
}

enum EstadoElemento: String, Codable, CaseIterable, Identifiable, Sendable {
    case nuevo = "NUEVO"
    case bueno = "BUENO"
    case usado = "USADO"
    case danado = "DANADO"

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .nuevo: "Nuevo"
        case .bueno: "Buen estado"
        case .usado: "Uso normal"
        case .danado: "Dañado"
        }
    }

    var tono: Tono {
        switch self {
        case .nuevo, .bueno: .positivo
        case .usado: .neutro
        case .danado: .negativo
        }
    }
}

enum TipoInventario: String, Codable, CaseIterable, Identifiable, Sendable {
    case entrada = "ENTRADA"
    case salida = "SALIDA"

    var id: String { rawValue }
    var nombre: String { self == .entrada ? "Entrada" : "Salida" }
}

/// GET /api/habitaciones/{id}/inventarios
struct Inventario: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let idHabitacion: Int
    let numeroHabitacion: Int
    let piso: PisoBreve
    let idContrato: Int?
    let inquilino: String?
    let tipo: TipoInventario
    let fecha: Date
    let observaciones: String?
    let elementos: [Elemento]

    struct Elemento: Decodable, Identifiable, Hashable, Sendable {
        let id: Int
        let nombre: String
        let estado: EstadoElemento
        let observaciones: String?
        let tieneFoto: Bool
    }
}

/// POST /api/habitaciones/{id}/inventarios
struct InventarioRequest: Encodable, Sendable {
    struct Elemento: Encodable, Sendable {
        let nombre: String
        let estado: EstadoElemento
        let observaciones: String?
    }

    let tipo: TipoInventario
    let fecha: String
    let idContrato: Int?
    let observaciones: String?
    let elementos: [Elemento]
}
