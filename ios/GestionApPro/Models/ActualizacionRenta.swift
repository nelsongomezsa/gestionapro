import Foundation

enum IndiceRenta: String, Codable, CaseIterable, Identifiable, Sendable {
    case irav = "IRAV"
    case ipc = "IPC"
    case pactado = "PACTADO"

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .irav: "IRAV (INE)"
        case .ipc: "IPC (INE)"
        case .pactado: "Porcentaje pactado"
        }
    }
}

/// GET /api/contratos/{id}/actualizacion-renta
struct PropuestaRenta: Decodable, Sendable {
    let debida: Bool
    /// nil si el contrato termina antes del próximo aniversario.
    let fechaEfecto: Date?
    let indice: IndiceRenta
    let indiceRecomendado: IndiceRenta
    let periodoIndice: String?
    /// Máximo aplicable (el índice, sin pasar del IRAV); nil si no hay dato del INE o es pactado.
    let porcentaje: Decimal?
    /// El índice elegido superaba el IRAV y se ha limitado a él (LAU, art. 18.1).
    let limitadoPorIrav: Bool
    let rentaActual: Decimal
    let rentaNueva: Decimal?
    let fuente: String?
    let motivoIndice: String
    let aviso: String
}

/// GET /api/contratos/{id}/actualizaciones-renta
struct HistorialRenta: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let fechaEfecto: Date
    let indice: IndiceRenta
    let periodoIndice: String?
    let porcentaje: Decimal
    let rentaAnterior: Decimal
    let rentaNueva: Decimal
    let fuente: String?
}

/// POST /api/contratos/{id}/actualizacion-renta
struct ConfirmacionRenta: Encodable, Sendable {
    let fechaEfecto: String
    let indice: IndiceRenta
    let porcentaje: Decimal?
}
