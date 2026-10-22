import Foundation

/// Una petición a la API con el tipo de su respuesta.
struct Endpoint<Respuesta: Decodable & Sendable>: Sendable {
    let metodo: String
    let ruta: String
    var cuerpo: Data? = nil
    /// false solo para login/registro: ahí un 401 son credenciales malas, no una sesión caducada.
    var requiereAuth = true
}

private func json(_ valor: some Encodable) -> Data? {
    try? JSONCoding.encoder().encode(valor)
}

extension Endpoint where Respuesta == TokenResponse {
    static func login(email: String, password: String) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/auth/login",
                 cuerpo: json(LoginRequest(email: email, password: password)), requiereAuth: false)
    }
}

extension Endpoint where Respuesta == Usuario {
    static let me = Endpoint(metodo: "GET", ruta: "/api/me")
}

extension Endpoint where Respuesta == [Piso] {
    static let pisos = Endpoint(metodo: "GET", ruta: "/api/pisos")
}

extension Endpoint where Respuesta == Piso {
    static func piso(id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/pisos/\(id)")
    }
}

extension Endpoint where Respuesta == ItpResponse {
    static let itp = Endpoint(metodo: "GET", ruta: "/api/calculadora/itp")
}

extension Endpoint where Respuesta == RentabilidadResponse {
    static func rentabilidad(_ req: RentabilidadRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/calculadora/rentabilidad", cuerpo: json(req))
    }
}
