import Foundation
import Observation

/// Estado de la sesión: token en el Keychain + usuario de GET /api/me.
@MainActor
@Observable
final class SesionStore {

    enum Estado: Equatable {
        /// Al arrancar, mientras se comprueba si el token guardado sigue valiendo.
        case comprobando
        case sinSesion
        case conectado(Usuario)
        /// Hay token pero no se pudo comprobar (p. ej. sin conexión): no se borra el token.
        case errorAlRestaurar(String)
    }

    private(set) var estado: Estado = .comprobando
    /// Aviso para la pantalla de login (p. ej. "Tu sesión ha caducado").
    var aviso: String?

    let api: APIClient
    private let tokens: any TokenStore

    init(baseURL: URL = AppConfig.apiBaseURL,
         tokens: any TokenStore = KeychainTokenStore(),
         session: URLSession = .shared) {
        // El cliente avisa de los 401 a esta sesión a través de un relevo débil,
        // porque se crea antes de que exista `self`.
        let relevo = RelevoNoAutorizado()
        self.tokens = tokens
        self.api = APIClient(baseURL: baseURL, session: session, tokens: tokens,
                             alNoAutorizado: { await relevo.notificar() })
        relevo.sesion = self
    }

    var usuario: Usuario? {
        if case let .conectado(u) = estado { return u }
        return nil
    }

    /// Al abrir la app: si hay token, se valida con /api/me.
    func restaurar() async {
        guard tokens.leer() != nil else {
            estado = .sinSesion
            return
        }
        estado = .comprobando
        do {
            estado = .conectado(try await api.enviar(.me))
        } catch .noAutorizado {
            // Ya gestionado por sesionCaducada().
        } catch {
            estado = .errorAlRestaurar(error.localizedDescription)
        }
    }

    func iniciarSesion(email: String, password: String) async throws(APIError) {
        let respuesta = try await api.enviar(.login(email: email, password: password))
        do {
            try tokens.guardar(respuesta.token)
        } catch {
            throw .red("No se pudo guardar la sesión en el llavero")
        }
        aviso = nil
        estado = .conectado(respuesta.usuario)
    }

    /// Tras editar el perfil (PATCH /api/me).
    func actualizar(usuario: Usuario) {
        if case .conectado = estado { estado = .conectado(usuario) }
    }

    func cerrarSesion() {
        tokens.borrar()
        estado = .sinSesion
    }

    /// 401 en cualquier petición autenticada: token caducado o revocado.
    func sesionCaducada() {
        guard estado != .sinSesion else { return }
        tokens.borrar()
        aviso = "Tu sesión ha caducado. Vuelve a iniciar sesión."
        estado = .sinSesion
    }
}

@MainActor
private final class RelevoNoAutorizado {
    weak var sesion: SesionStore?

    func notificar() {
        sesion?.sesionCaducada()
    }
}
