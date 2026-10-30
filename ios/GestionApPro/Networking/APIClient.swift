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
        let (datos, http) = try await ejecutar(metodo: endpoint.metodo, ruta: endpoint.ruta, consulta: endpoint.consulta,
                                               cuerpo: endpoint.cuerpo, requiereAuth: endpoint.requiereAuth,
                                               acepta: "application/json")
        // 204 No Content (borrados): no hay cuerpo que decodificar.
        if let vacio = SinContenido() as? R, datos.isEmpty || http.statusCode == 204 {
            return vacio
        }
        do {
            return try JSONCoding.decoder().decode(R.self, from: datos)
        } catch {
            throw .decodificacion(String(describing: error))
        }
    }

    /// Descarga un archivo (p. ej. el contrato en PDF) con el mismo manejo de errores.
    func descargar(_ ruta: String, consulta: [URLQueryItem] = [], tipo: String = "application/pdf") async throws(APIError) -> Data {
        try await ejecutar(metodo: "GET", ruta: ruta, consulta: consulta, cuerpo: nil, requiereAuth: true, acepta: tipo).0
    }

    /// Sube un archivo (foto o factura) como multipart/form-data en el campo "archivo".
    func subir<R: Decodable & Sendable>(_ ruta: String, archivo: Data, nombre: String, tipo: String,
                                        respuesta: R.Type = R.self) async throws(APIError) -> R {
        let limite = "GestionAp-\(UUID().uuidString)"
        var cuerpo = Data()
        cuerpo.append(Data("--\(limite)\r\n".utf8))
        cuerpo.append(Data("Content-Disposition: form-data; name=\"archivo\"; filename=\"\(nombre)\"\r\n".utf8))
        cuerpo.append(Data("Content-Type: \(tipo)\r\n\r\n".utf8))
        cuerpo.append(archivo)
        cuerpo.append(Data("\r\n--\(limite)--\r\n".utf8))
        let (datos, _) = try await ejecutar(metodo: "POST", ruta: ruta, consulta: [], cuerpo: cuerpo, requiereAuth: true,
                                            acepta: "application/json", tipoCuerpo: "multipart/form-data; boundary=\(limite)")
        do {
            return try JSONCoding.decoder().decode(R.self, from: datos)
        } catch {
            throw .decodificacion(String(describing: error))
        }
    }

    private func ejecutar(metodo: String, ruta: String, consulta: [URLQueryItem], cuerpo: Data?,
                          requiereAuth: Bool, acepta: String,
                          tipoCuerpo: String = "application/json") async throws(APIError) -> (Data, HTTPURLResponse) {
        var url = baseURL.appending(path: ruta)
        let parametros = consulta.filter { $0.value != nil }
        if !parametros.isEmpty { url.append(queryItems: parametros) }
        var peticion = URLRequest(url: url)
        peticion.httpMethod = metodo
        // También se acepta JSON para poder leer el cuerpo de error de la API.
        peticion.setValue(acepta == "application/json" ? acepta : "\(acepta), application/json", forHTTPHeaderField: "Accept")
        if let cuerpo {
            peticion.httpBody = cuerpo
            peticion.setValue(tipoCuerpo, forHTTPHeaderField: "Content-Type")
        }
        if requiereAuth {
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
        guard (200..<300).contains(http.statusCode) else {
            let cuerpo = try? JSONCoding.decoder().decode(ErrorAPI.self, from: datos)
            if http.statusCode == 401 && requiereAuth {
                await alNoAutorizado()
                throw .noAutorizado(cuerpo)
            }
            throw .respuesta(status: http.statusCode, cuerpo)
        }
        return (datos, http)
    }
}

/// Respuesta sin cuerpo (204), p. ej. al borrar.
struct SinContenido: Decodable, Sendable {}
