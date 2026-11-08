import Foundation

/// GET /api/habitaciones
struct Habitacion: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let numero: Int
    /// V12: habitación, plaza o trastero, con m², planta y coche o moto (opcionales).
    var tipo: TipoUnidad? = nil
    var metros: Decimal? = nil
    var planta: String? = nil
    var vehiculo: Vehiculo? = nil
    let precio: Decimal
    let estado: EstadoHabitacion
    let piso: PisoBreve
    /// Inquilino del contrato activo hoy; nil si no hay.
    let inquilinoActual: InquilinoActual?
    let idContratoActivo: Int?
    let diasAlquilada: Int?
    /// Libre (o en mantenimiento) desde esta fecha: el día siguiente al fin de su último contrato.
    /// nil si está alquilada o nunca tuvo contrato.
    var libreDesde: Date? = nil

    struct InquilinoActual: Decodable, Hashable, Sendable {
        let id: Int
        let nombre: String
    }
}

struct PisoBreve: Codable, Hashable, Sendable {
    let id: Int
    let direccion: String
    let ciudad: String
    var tipo: TipoInmueble? = nil

    var tipoInmueble: TipoInmueble { tipo ?? .vivienda }
}

extension Habitacion {
    var unidad: TipoUnidad { tipo ?? .habitacion }
    /// "Hab. 3", "Plaza 3", "Trastero 3".
    var etiqueta: String { unidad.etiqueta(numero) }
    /// "Habitación 3", "Plaza 3", "Trastero 3".
    var titulo: String { unidad.titulo(numero) }
    /// "Planta -1 · 12 m² · Coche" (lo que se haya indicado); nil si nada.
    var detalle: String? {
        var partes: [String] = []
        if let planta, !planta.isEmpty { partes.append(String(localized: "Planta \(planta)")) }
        if let metros { partes.append("\(Formato.numero(metros.double)) m²") }
        if let vehiculo { partes.append(vehiculo.nombre) }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }
}

enum EstadoHabitacion: String, Codable, CaseIterable, Identifiable, Sendable {
    case disponible, alquilada, mantenimiento

    var id: Self { self }

    var nombre: String { nombre(para: .habitacion) }

    /// Con el género de la unidad: "Alquilada" (habitación, plaza) o "Alquilado" (trastero).
    func nombre(para unidad: TipoUnidad) -> String {
        switch self {
        case .disponible: String(localized: "Disponible")
        case .alquilada: unidad == .trastero ? String(localized: "Alquilado") : String(localized: "Alquilada")
        case .mantenimiento: String(localized: "Mantenimiento")
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
    var tipo: TipoUnidad? = nil
    var metros: Decimal? = nil
    var planta: String? = nil
    var vehiculo: Vehiculo? = nil
}

struct CambioEstadoRequest: Encodable, Sendable {
    let estado: EstadoHabitacion
}
