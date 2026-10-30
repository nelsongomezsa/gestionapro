import Foundation

/// GET /api/contratos/{id}/fianza
struct Fianza: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let idContrato: Int
    let inquilino: String
    let numeroHabitacion: Int
    let piso: PisoBreve
    let importe: Decimal
    let fechaCobro: Date?
    let fechaDeposito: Date?
    let organismoDeposito: String?
    let referenciaDeposito: String?
    let fechaDevolucion: Date?
    let importeDevuelto: Decimal?
    let motivoRetencion: String?
    let notas: String?
    let estado: Estado
    /// El importe entero mientras no se registre la devolución.
    let pendienteDevolver: Decimal
    /// Lo que se quedó el propietario al devolverla.
    let retenido: Decimal

    enum Estado: String, Decodable, Sendable {
        case sinDepositar = "SIN_DEPOSITAR"
        case depositada = "DEPOSITADA"
        case devuelta = "DEVUELTA"
        case devueltaParcial = "DEVUELTA_PARCIAL"

        var nombre: String {
            switch self {
            case .sinDepositar: "Sin depositar"
            case .depositada: "Depositada"
            case .devuelta: "Devuelta"
            case .devueltaParcial: "Devuelta en parte"
            }
        }

        var tono: Tono {
            switch self {
            case .sinDepositar: .aviso
            case .depositada: .primario
            case .devuelta: .positivo
            case .devueltaParcial: .neutro
            }
        }
    }
}

/// GET /api/fianzas
struct ResumenFianzas: Decodable, Sendable {
    let fianzas: [Fianza]
    let totalPendienteDevolver: Decimal
}

/// PUT /api/contratos/{id}/fianza
struct FianzaRequest: Encodable, Sendable {
    let importe: Decimal
    let fechaCobro: String?
    let fechaDeposito: String?
    let organismoDeposito: String?
    let referenciaDeposito: String?
    let notas: String?
}

/// POST /api/contratos/{id}/fianza/devolucion
struct DevolucionFianzaRequest: Encodable, Sendable {
    let fechaDevolucion: String
    let importeDevuelto: Decimal
    let motivoRetencion: String?
}
