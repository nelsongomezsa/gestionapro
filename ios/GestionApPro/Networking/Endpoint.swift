import Foundation

/// Una petición a la API con el tipo de su respuesta.
struct Endpoint<Respuesta: Decodable & Sendable>: Sendable {
    let metodo: String
    let ruta: String
    /// Parámetros de la URL (?piso=1&estado=disponible). Los nil se omiten.
    var consulta: [URLQueryItem] = []
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

// MARK: Habitaciones

extension Endpoint where Respuesta == [Habitacion] {
    static func habitaciones(piso: Int? = nil, estado: EstadoHabitacion? = nil) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/habitaciones",
                 consulta: [URLQueryItem(name: "piso", value: piso.map(String.init)),
                            URLQueryItem(name: "estado", value: estado?.rawValue)])
    }
}

extension Endpoint where Respuesta == Habitacion {
    static func crearHabitacion(_ req: HabitacionRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/habitaciones", cuerpo: json(req))
    }

    static func actualizarHabitacion(id: Int, _ req: HabitacionRequest) -> Self {
        Endpoint(metodo: "PUT", ruta: "/api/habitaciones/\(id)", cuerpo: json(req))
    }

    static func cambiarEstado(habitacion id: Int, a estado: EstadoHabitacion) -> Self {
        Endpoint(metodo: "PATCH", ruta: "/api/habitaciones/\(id)/estado", cuerpo: json(CambioEstadoRequest(estado: estado)))
    }
}

extension Endpoint where Respuesta == SinContenido {
    static func borrarHabitacion(id: Int) -> Self {
        Endpoint(metodo: "DELETE", ruta: "/api/habitaciones/\(id)")
    }

    static func borrarInquilino(id: Int) -> Self {
        Endpoint(metodo: "DELETE", ruta: "/api/inquilinos/\(id)")
    }
}

// MARK: Inquilinos

extension Endpoint where Respuesta == [Inquilino] {
    static let inquilinos = Endpoint(metodo: "GET", ruta: "/api/inquilinos")
}

extension Endpoint where Respuesta == Inquilino {
    static func inquilino(id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/inquilinos/\(id)")
    }

    static func crearInquilino(_ req: InquilinoRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/inquilinos", cuerpo: json(req))
    }

    static func actualizarInquilino(id: Int, _ req: InquilinoRequest) -> Self {
        Endpoint(metodo: "PUT", ruta: "/api/inquilinos/\(id)", cuerpo: json(req))
    }
}

extension Endpoint where Respuesta == QrPago {
    static func qrPago(inquilino id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/inquilinos/\(id)/qr-pago")
    }
}

extension Endpoint where Respuesta == Invitacion {
    static func invitar(inquilino id: Int) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/inquilinos/\(id)/invitaciones")
    }
}

// MARK: Perfil

extension Endpoint where Respuesta == Usuario {
    static func actualizarPerfil(_ req: ActualizarPerfilRequest) -> Self {
        Endpoint(metodo: "PATCH", ruta: "/api/me", cuerpo: json(req))
    }
}
