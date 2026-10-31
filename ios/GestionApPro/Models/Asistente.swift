import Foundation

/// GET /api/asistente/estado
struct EstadoAsistente: Decodable, Sendable {
    let disponible: Bool
    let mensaje: String
    let usadosHoy: Int
    let limiteDiario: Int
}

/// Acción que propone el asistente; la app solo la ejecuta si el usuario la confirma.
struct AccionAsistente: Decodable, Hashable, Sendable {
    enum Tipo: String, Decodable, Sendable {
        case registrarPago = "REGISTRAR_PAGO"
        case crearIncidencia = "CREAR_INCIDENCIA"
        case recordatorio = "RECORDATORIO"
    }

    struct Datos: Decodable, Hashable, Sendable {
        var idContrato: Int?
        var cantidad: Decimal?
        var fechaPago: String?
        var metodoPago: MetodoPago?
        var idHabitacion: Int?
        var descripcion: String?
        var texto: String?
    }

    let tipo: Tipo
    let resumen: String
    let datos: Datos
}

/// POST /api/asistente/conversar
struct ContestacionAsistente: Decodable, Sendable {
    let respuesta: String
    let acciones: [AccionAsistente]
    let usadosHoy: Int
    let limiteDiario: Int
}

struct PreguntaAsistente: Encodable, Sendable {
    struct Turno: Encodable, Sendable {
        let delUsuario: Bool
        let texto: String
    }

    let mensaje: String
    let historial: [Turno]
}

/// POST /api/asistente/clasificar-incidencia
struct ClasificacionIncidencia: Decodable, Sendable {
    let categoria: String
    let urgencia: String
    let motivo: String
}

/// POST /api/asistente/leer-factura
struct PropuestaGastoIA: Decodable, Sendable {
    let proveedor: String?
    let concepto: String?
    let fecha: String?
    let importe: Decimal
    let categoria: CategoriaGasto
    let observaciones: String?
}
