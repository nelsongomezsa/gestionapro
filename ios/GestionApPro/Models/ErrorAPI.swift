import Foundation

/// Formato único de error de la API (ErrorResponse en el backend).
struct ErrorAPI: Decodable, Equatable, Sendable {
    let status: Int
    let codigo: String
    let mensaje: String
    let path: String?
    let errores: [CampoError]?

    struct CampoError: Decodable, Equatable, Sendable {
        let campo: String
        let mensaje: String
    }
}
