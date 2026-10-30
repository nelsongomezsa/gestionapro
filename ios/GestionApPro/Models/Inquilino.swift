import Foundation

/// GET /api/inquilinos (sin contratos ni pagos) y /api/inquilinos/{id} (ficha completa).
struct Inquilino: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let nombre: String
    let apellidos: String
    let dni: String
    let telefono: String?
    let email: String?
    let tieneCuentaApp: Bool
    let contratoActivo: ContratoBreve?
    let contratos: [ContratoBreve]
    let pagos: [PagoBreve]

    var nombreCompleto: String { "\(nombre) \(apellidos)" }
}

struct ContratoBreve: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let idHabitacion: Int
    let numeroHabitacion: Int
    let piso: PisoBreve
    let fechaInicio: Date
    let fechaFin: Date
    let precioMensual: Decimal
    let activo: Bool
    let vencimiento: NivelVencimiento
}

struct PagoBreve: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let idContrato: Int
    let fechaPago: Date
    let cantidad: Decimal
    let metodoPago: MetodoPago
}

enum MetodoPago: String, Codable, CaseIterable, Identifiable, Sendable {
    case transferencia, efectivo, domiciliacion

    var id: Self { self }

    var nombre: String {
        switch self {
        case .transferencia: "Transferencia"
        case .efectivo: "Efectivo"
        case .domiciliacion: "Domiciliación"
        }
    }
}

/// Mismos umbrales que el escritorio: crítico si vence en 7 días o menos, próximo en 30.
enum NivelVencimiento: String, Decodable, Sendable {
    case vencido = "VENCIDO"
    case critico = "CRITICO"
    case proximo = "PROXIMO"
    case normal = "NORMAL"

    var texto: String {
        switch self {
        case .vencido: "Vencido"
        case .critico: "Vence en ≤ 7 días"
        case .proximo: "Vence en ≤ 30 días"
        case .normal: "Vigente"
        }
    }

    /// Para la insignia junto a "Quedan N días" (sin repetir los días).
    var estadoCorto: String {
        switch self {
        case .vencido: "Vencido"
        case .critico: "Urgente"
        case .proximo: "Por vencer"
        case .normal: "Vigente"
        }
    }

    var tono: Tono {
        switch self {
        case .vencido: .neutro
        case .critico: .negativo
        case .proximo: .aviso
        case .normal: .positivo
        }
    }
}

/// POST y PUT /api/inquilinos
struct InquilinoRequest: Encodable, Sendable {
    var nombre = ""
    var apellidos = ""
    var dni = ""
    var telefono = ""
    var email = ""
}

/// GET /api/inquilinos/{id}/qr-pago
struct QrPago: Decodable, Sendable {
    let payload: String
    let beneficiario: String
    let iban: String
    let importe: Decimal
    let concepto: String
}

/// POST /api/inquilinos/{id}/invitaciones
struct Invitacion: Decodable, Sendable {
    let codigo: String
    let idInquilino: Int
    let expira: Date
    let emailEnviado: Bool
}

/// PATCH /api/me: solo se envían los campos no nulos.
struct ActualizarPerfilRequest: Encodable, Sendable {
    var nombre: String? = nil
    var email: String? = nil
    var dni: String? = nil
    var iban: String? = nil
}
