import Foundation
import XCTest

/// Datos que un recorrido prepara por la API antes de empezar y retira al terminar, para no depender
/// de lo que haya en la base (p. ej. un contrato que ya se firmó en una pasada anterior).
/// Todo lo que crea usa la habitación 990, reservada para estos tests: `ios/scripts/limpiar-datos-uitest.sql`
/// borra lo que la API no permite borrar (contratos con historial) en la base de pruebas.
struct DatosPrueba {
    static let numeroHabitacion = 990

    let api: URL
    let token: String
    private(set) var idContrato: Int?
    private(set) var idHabitacion: Int?

    /// nil si no hay URL de la API o credenciales en el entorno (el recorrido usará los datos existentes).
    init?() {
        let env = ProcessInfo.processInfo.environment
        guard let base = env["CAPTURAS_API"], let url = URL(string: base),
              let email = env["CAPTURAS_EMAIL"], let password = env["CAPTURAS_PASSWORD"],
              let r = try? Self.pedir(url, "POST", "/api/auth/login", ["email": email, "password": password]),
              let token = r["token"] as? String else { return nil }
        self.api = url
        self.token = token
    }

    /// Contrato activo y sin firmar del inquilino de demo en una habitación nueva (la 990) de su primer piso.
    mutating func contratoSinFirmar(idInquilino: Int) throws -> Int {
        let pisos = try Self.pedirLista(api, "GET", "/api/pisos", token: token)
        let idPiso = try XCTUnwrap(pisos.first?["id"] as? Int, "No hay pisos")
        let hab = try Self.pedir(api, "POST", "/api/habitaciones",
                                 ["idPiso": idPiso, "numero": Self.numeroHabitacion, "precio": "500.00"], token: token)
        idHabitacion = try XCTUnwrap(hab["id"] as? Int)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Madrid")
        let hoy = Date()
        let c = try Self.pedir(api, "POST", "/api/contratos", [
            "idHabitacion": idHabitacion!, "idInquilino": idInquilino,
            "fechaInicio": f.string(from: hoy.addingTimeInterval(-86_400 * 30)),
            "fechaFin": f.string(from: hoy.addingTimeInterval(86_400 * 330)),
            "precioMensual": "500.00"], token: token)
        idContrato = try XCTUnwrap(c["id"] as? Int)
        return idContrato!
    }

    /// Ids de los pagos registrados en el mes actual (para borrar al final solo los que cree el test).
    func idsPagosDelMes() throws -> Set<Int> {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Madrid")
        let pagos = try Self.pedirLista(api, "GET", "/api/pagos?mes=\(f.string(from: Date()))", token: token)
        return Set(pagos.compactMap { $0["id"] as? Int })
    }

    func borrarPagos(_ ids: Set<Int>) {
        for id in ids { _ = try? Self.pedir(api, "DELETE", "/api/pagos/\(id)", nil, token: token) }
    }

    /// Lo que la API deja: finalizar el contrato (libera la habitación). El resto, el script SQL.
    func limpiar() {
        if let idContrato { _ = try? Self.pedir(api, "POST", "/api/contratos/\(idContrato)/finalizar", nil, token: token) }
    }

    /// Id del inquilino enlazado a una cuenta (login con sus credenciales).
    static func idInquilino(api: URL, email: String, password: String) throws -> Int {
        let r = try pedir(api, "POST", "/api/auth/login", ["email": email, "password": password])
        let usuario = try XCTUnwrap(r["usuario"] as? [String: Any])
        return try XCTUnwrap(usuario["idInquilino"] as? Int)
    }

    // MARK: - HTTP síncrono (solo para preparar datos en los tests)

    static func pedir(_ api: URL, _ metodo: String, _ ruta: String, _ cuerpo: [String: Any]?, token: String? = nil) throws -> [String: Any] {
        let datos = try enviar(api, metodo, ruta, cuerpo, token: token)
        if datos.isEmpty { return [:] }
        return (try JSONSerialization.jsonObject(with: datos) as? [String: Any]) ?? [:]
    }

    static func pedirLista(_ api: URL, _ metodo: String, _ ruta: String, token: String) throws -> [[String: Any]] {
        (try JSONSerialization.jsonObject(with: enviar(api, metodo, ruta, nil, token: token)) as? [[String: Any]]) ?? []
    }

    private static func enviar(_ api: URL, _ metodo: String, _ ruta: String, _ cuerpo: [String: Any]?, token: String?) throws -> Data {
        var p = URLRequest(url: URL(string: api.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + ruta)!)
        p.httpMethod = metodo
        p.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { p.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let cuerpo { p.httpBody = try JSONSerialization.data(withJSONObject: cuerpo) }
        let hecho = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var resultado: (Data?, URLResponse?, Error?)
        URLSession.shared.dataTask(with: p) { d, r, e in resultado = (d, r, e); hecho.signal() }.resume()
        hecho.wait()
        if let e = resultado.2 { throw e }
        let status = (resultado.1 as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw NSError(domain: "DatosPrueba", code: status,
                          userInfo: [NSLocalizedDescriptionKey: "\(metodo) \(ruta) → \(status): \(String(decoding: resultado.0 ?? Data(), as: UTF8.self))"])
        }
        return resultado.0 ?? Data()
    }
}
