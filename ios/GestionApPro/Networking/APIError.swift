import Foundation

/// Errores de la API traducidos a algo que la interfaz pueda mostrar.
enum APIError: Error, Equatable, LocalizedError {
    /// 401 en una ruta autenticada: token caducado o no válido. La sesión se cierra.
    case noAutorizado(ErrorAPI?)
    /// Cualquier otra respuesta no 2xx, con el cuerpo de error de la API si lo había.
    case respuesta(status: Int, ErrorAPI?)
    /// No se pudo llegar al servidor.
    case sinConexion
    case red(String)
    case decodificacion(String)

    var errorDescription: String? {
        switch self {
        case .noAutorizado:
            return "Tu sesión ha caducado. Vuelve a iniciar sesión."
        case let .respuesta(status, cuerpo):
            guard let cuerpo else { return "Error del servidor (código \(status))." }
            guard let errores = cuerpo.errores, !errores.isEmpty else { return cuerpo.mensaje }
            return ([cuerpo.mensaje] + errores.map { "• \($0.campo): \($0.mensaje)" }).joined(separator: "\n")
        case .sinConexion:
            return "No se puede conectar con el servidor. Comprueba que la API está en marcha."
        case let .red(detalle):
            return "Error de red: \(detalle)"
        case .decodificacion:
            return "La respuesta del servidor no tiene el formato esperado."
        }
    }

    /// Código estable de la API (VALIDACION, NO_ENCONTRADO...), si lo hay.
    var codigo: String? {
        switch self {
        case let .noAutorizado(cuerpo), let .respuesta(_, cuerpo): cuerpo?.codigo
        default: nil
        }
    }
}
