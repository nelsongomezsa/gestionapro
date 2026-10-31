import Foundation

/// GET /api/contratos/{id}/mensajes
struct MensajeChat: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let idContrato: Int
    let idIncidencia: Int?
    let autor: String
    /// Lo he escrito yo (burbuja a la derecha).
    let mio: Bool
    let texto: String
    let fecha: Date
    let leido: Bool
}

/// GET /api/conversaciones
struct Conversacion: Decodable, Identifiable, Hashable, Sendable {
    let idContrato: Int
    let idIncidencia: Int?
    let con: String
    let asunto: String
    let ultimoMensaje: String
    let fecha: Date
    let ultimoMio: Bool
    let sinLeer: Int

    var id: String { "\(idContrato)/\(idIncidencia.map(String.init) ?? "-")" }
}

struct MensajeRequest: Encodable, Sendable {
    let texto: String
    let idIncidencia: Int?
}

/// GET /api/contratos/{id}/firmas
struct EstadoFirmas: Decodable, Sendable {
    struct Firma: Decodable, Hashable, Sendable {
        let parte: ParteFirma
        let nombre: String
        let dni: String?
        let fecha: String
        let proveedor: String
        /// El contrato no ha cambiado desde que firmó.
        let vigente: Bool
    }

    let firmas: [Firma]
    let completo: Bool
    let cambiadoTrasFirmar: Bool
}

enum ParteFirma: String, Codable, CaseIterable, Identifiable, Sendable {
    case arrendador = "ARRENDADOR"
    case arrendatario = "ARRENDATARIO"

    var id: String { rawValue }
    var nombre: String { self == .arrendador ? "Arrendador" : "Arrendatario" }
}
