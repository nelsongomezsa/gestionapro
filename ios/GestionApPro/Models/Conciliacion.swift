import Foundation

/// POST /api/conciliacion/analizar
struct AnalisisConciliacion: Decodable, Sendable {
    struct Movimiento: Decodable, Hashable, Sendable {
        let fecha: Date
        let concepto: String
        let importe: Decimal
    }

    struct Propuesta: Decodable, Hashable, Sendable {
        let idContrato: Int
        let inquilino: String
        let numeroHabitacion: Int
        let direccion: String
        let renta: Decimal
        let puntuacion: Int
        /// ALTA, MEDIA o BAJA
        let confianza: String
        let yaRegistrado: Bool
        let preseleccionada: Bool
    }

    struct Analizado: Decodable, Identifiable, Hashable, Sendable {
        let indice: Int
        let movimiento: Movimiento
        let propuesta: Propuesta
        var id: Int { indice }
    }

    let propuestas: [Analizado]
    let sinPropuesta: [Movimiento]
}

/// POST /api/conciliacion/confirmar
struct ConfirmarConciliacion: Encodable, Sendable {
    struct Pago: Encodable, Sendable {
        let idContrato: Int
        let fecha: String
        let importe: Decimal
        let metodoPago: MetodoPago
    }

    let pagos: [Pago]
}

struct ConciliacionConfirmada: Decodable, Sendable {
    let pagos: [Pago]
}
