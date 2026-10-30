import Foundation

/// Cliente HTTP de la API: añade el token, decodifica la respuesta y convierte
/// cualquier fallo en APIError (incluido el JSON de error de la API).
final class APIClient: Sendable {
    let baseURL: URL
    private let session: URLSession
    private let tokens: any TokenStore
    /// Se llama ante un 401 en una ruta autenticada, para volver al login.
    private let alNoAutorizado: @Sendable () async -> Void

    init(baseURL: URL,
         session: URLSession = .shared,
         tokens: any TokenStore,
         alNoAutorizado: @escaping @Sendable () async -> Void = {}) {
        self.baseURL = baseURL
        self.session = session
        self.tokens = tokens
        self.alNoAutorizado = alNoAutorizado
    }

    func enviar<R>(_ endpoint: Endpoint<R>) async throws(APIError) -> R {
        var url = baseURL.appending(path: endpoint.ruta)
        let parametros = endpoint.consulta.filter { $0.value != nil }
        if !parametros.isEmpty { url.append(queryItems: parametros) }
        var peticion = URLRequest(url: url)
        peticion.httpMethod = endpoint.metodo
        peticion.setValue("application/json", forHTTPHeaderField: "Accept")
        if let cuerpo = endpoint.cuerpo {
            peticion.httpBody = cuerpo
            peticion.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if endpoint.requiereAuth {
            guard let token = tokens.leer() else {
                await alNoAutorizado()
                throw .noAutorizado(nil)
            }
            peticion.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await session.data(for: peticion)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost,
                 .timedOut, .networkConnectionLost:
                throw .sinConexion
            default:
                throw .red(error.localizedDescription)
            }
        } catch {
            throw .red(error.localizedDescription)
        }

        guard let http = respuesta as? HTTPURLResponse else {
            throw .red("Respuesta no HTTP")
        }
        let decoder = JSONCoding.decoder()

        guard (200..<300).contains(http.statusCode) else {
            let cuerpo = try? decoder.decode(ErrorAPI.self, from: datos)
            if http.statusCode == 401 && endpoint.requiereAuth {
                await alNoAutorizado()
                throw .noAutorizado(cuerpo)
            }
            throw .respuesta(status: http.statusCode, cuerpo)
        }

        // 204 No Content (borrados): no hay cuerpo que decodificar.
        if let vacio = SinContenido() as? R, datos.isEmpty || http.statusCode == 204 {
            return vacio
        }
        do {
            return try decoder.decode(R.self, from: datos)
        } catch {
            throw .decodificacion(String(describing: error))
        }
    }
}

/// Respuesta sin cuerpo (204), p. ej. al borrar.
struct SinContenido: Decodable, Sendable {}
