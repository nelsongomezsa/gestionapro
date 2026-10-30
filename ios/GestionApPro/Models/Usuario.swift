import Foundation

/// GET /api/me y TokenResponse.usuario.
struct Usuario: Codable, Equatable, Sendable {
    let id: Int
    let nombre: String
    let email: String
    let rol: Rol
    /// Solo para INQUILINO.
    let idInquilino: Int?
    var dni: String? = nil
    /// Con espacios cada 4 caracteres; lo usa el QR de pago de sus inquilinos.
    var iban: String? = nil
}

enum Rol: String, Codable, Sendable {
    case admin = "ADMIN"
    case propietario = "PROPIETARIO"
    case inquilino = "INQUILINO"
    /// Un rol que esta versión de la app no conoce: se trata como sin permisos de gestión.
    case desconocido

    init(from decoder: Decoder) throws {
        let valor = try decoder.singleValueContainer().decode(String.self)
        self = Rol(rawValue: valor) ?? .desconocido
    }

    var gestionaPisos: Bool { self == .admin || self == .propietario }

    var nombreVisible: String {
        switch self {
        case .admin: "Administrador"
        case .propietario: "Propietario"
        case .inquilino: "Inquilino"
        case .desconocido: "Desconocido"
        }
    }
}

/// POST /api/auth/login
struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

/// Respuesta de login y de registro.
struct TokenResponse: Decodable, Sendable {
    let token: String
    let tipo: String
    let expira: Date
    let usuario: Usuario
}

/// POST /api/auth/register-inquilino: el inquilino crea su cuenta con el código de su propietario.
struct RegistroInquilinoRequest: Encodable, Sendable {
    let codigo: String
    let email: String
    let password: String
}

/// PUT /api/me/password
struct CambioPasswordRequest: Encodable, Sendable {
    let actual: String
    let nueva: String
}

/// GET /api/usuarios (solo admin).
struct UsuarioAdmin: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let nombre: String
    let email: String
    let rol: Rol
    let activo: Bool
}

/// POST /api/usuarios: solo ADMIN o PROPIETARIO (los inquilinos entran con invitación).
struct NuevoUsuarioRequest: Encodable, Sendable {
    let nombre: String
    let email: String
    let password: String
    let rol: Rol
}

struct CambioActivoRequest: Encodable, Sendable { let activo: Bool }
struct CambioRolRequest: Encodable, Sendable { let rol: Rol }
