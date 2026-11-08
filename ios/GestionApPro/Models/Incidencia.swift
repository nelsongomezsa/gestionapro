import Foundation

/// GET /api/incidencias
struct Incidencia: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let descripcion: String
    let estado: EstadoIncidencia
    let fecha: Date
    let costeReparacion: Decimal
    let habitacion: Contrato.HabitacionBreve
    let piso: PisoBreve
    let inquilino: Breve
    /// Días desde que se comunicó.
    let dias: Int

    struct Breve: Decodable, Hashable, Sendable {
        let id: Int
        let nombre: String
    }
}

/// Flujo del escritorio: pendiente → en proceso → resuelta.
enum EstadoIncidencia: String, Codable, CaseIterable, Identifiable, Sendable {
    case pendiente
    case enProceso = "en_proceso"
    case resuelta

    var id: Self { self }

    var nombre: String {
        switch self {
        case .pendiente: "Pendiente"
        case .enProceso: "En proceso"
        case .resuelta: "Resuelta"
        }
    }

    var icono: String {
        switch self {
        case .pendiente: "exclamationmark.circle"
        case .enProceso: "hammer"
        case .resuelta: "checkmark.circle"
        }
    }

    var tono: Tono {
        switch self {
        case .pendiente: .negativo
        case .enProceso: .aviso
        case .resuelta: .positivo
        }
    }

    var siguiente: EstadoIncidencia? {
        switch self {
        case .pendiente: .enProceso
        case .enProceso: .resuelta
        case .resuelta: nil
        }
    }

    /// Texto del botón que avanza al siguiente estado.
    var accionSiguiente: String? {
        switch self {
        case .pendiente: "Empezar"
        case .enProceso: "Resolver"
        case .resuelta: nil
        }
    }
}

/// POST /api/incidencias
struct IncidenciaRequest: Encodable, Sendable {
    var idHabitacion: Int?
    var idInquilino: Int?
    var descripcion: String
    var costeReparacion: Decimal?
}

struct CambioEstadoIncidencia: Encodable, Sendable {
    let estado: EstadoIncidencia?
}

/// PATCH /api/incidencias/{id}
struct ActualizarIncidencia: Encodable, Sendable {
    var descripcion: String? = nil
    var costeReparacion: Decimal? = nil
}

/// PUT /api/pisos/{id}
struct PisoRequest: Encodable, Sendable {
    let direccion: String
    let numeroHabitaciones: Int
    let idCiudad: Int
    let datosFinancieros: DatosFinancierosRequest?
    /// Solo al crear: habitaciones que se dan de alta con el piso (la API las ignora en un PUT).
    var habitaciones: [HabitacionInicial]? = nil
    /// V12: vivienda, garajes o trasteros. En un PUT, nil no lo cambia.
    var tipo: TipoInmueble? = nil

    struct HabitacionInicial: Encodable, Equatable, Sendable {
        let numero: Int
        let precio: Decimal
        var tipo: TipoUnidad? = nil
        var metros: Decimal? = nil
        var planta: String? = nil
        var vehiculo: Vehiculo? = nil
    }
}

struct DatosFinancierosRequest: Encodable, Sendable {
    var precioCompra: Decimal = 0
    var itpPagado: Decimal = 0
    var gastosNotaria: Decimal = 0
    var gastosRegistro: Decimal = 0
    var costeReforma: Decimal = 0
    var costeMobiliario: Decimal = 0
    var otrosGastosCompra: Decimal = 0
    var tieneHipoteca = false
    var importeHipoteca: Decimal = 0
    var tipoInteres: Decimal = 0
    var plazoAnos = 0
    var gastoIbiAnual: Decimal = 0
    var gastoComunidadMensual: Decimal = 0
    var gastoSeguroAnual: Decimal = 0
    var gastoMantenimientoAnual: Decimal = 0
    var valorMercadoActual: Decimal = 0
    var notas: String? = nil

    init() {}

    init(_ d: Piso.DatosFinancieros?) {
        guard let d else { return }
        precioCompra = d.precioCompra ?? 0
        itpPagado = d.itpPagado ?? 0
        gastosNotaria = d.gastosNotaria ?? 0
        gastosRegistro = d.gastosRegistro ?? 0
        costeReforma = d.costeReforma ?? 0
        costeMobiliario = d.costeMobiliario ?? 0
        otrosGastosCompra = d.otrosGastosCompra ?? 0
        tieneHipoteca = d.tieneHipoteca
        importeHipoteca = d.importeHipoteca ?? 0
        tipoInteres = d.tipoInteres ?? 0
        plazoAnos = d.plazoAnos ?? 0
        gastoIbiAnual = d.gastoIbiAnual ?? 0
        gastoComunidadMensual = d.gastoComunidadMensual ?? 0
        gastoSeguroAnual = d.gastoSeguroAnual ?? 0
        gastoMantenimientoAnual = d.gastoMantenimientoAnual ?? 0
        valorMercadoActual = d.valorMercadoActual ?? 0
        notas = d.notas
    }
}

/// Filtro de la lista de incidencias. "Abiertas" junta pendientes y en curso (la tarjeta de Inicio).
enum FiltroIncidencias: Hashable, CaseIterable, Sendable {
    case abiertas, pendientes, enProceso, resueltas, todas

    var nombre: String {
        switch self {
        case .abiertas: String(localized: "Abiertas")
        case .pendientes: String(localized: "Pendientes")
        case .enProceso: String(localized: "En proceso")
        case .resueltas: String(localized: "Resueltas")
        case .todas: String(localized: "Todas")
        }
    }

    func incluye(_ estado: EstadoIncidencia) -> Bool {
        switch self {
        case .abiertas: estado != .resuelta
        case .pendientes: estado == .pendiente
        case .enProceso: estado == .enProceso
        case .resueltas: estado == .resuelta
        case .todas: true
        }
    }

    /// Con un solo estado la insignia sería la misma en todas las filas.
    var variosEstados: Bool { self == .abiertas || self == .todas }
}
