import Foundation
@testable import GestionApPro

private final class MarcaBundle {}

/// JSON reales de la API (capturados de gestion_alquileres_pro; el token es ficticio).
enum Fixture {
    static func datos(_ nombre: String) throws -> Data {
        let url = try ruta(nombre)
        return try Data(contentsOf: url)
    }

    static func decodificar<T: Decodable>(_ tipo: T.Type, de nombre: String) throws -> T {
        try JSONCoding.decoder().decode(tipo, from: datos(nombre))
    }

    private static func ruta(_ nombre: String) throws -> URL {
        guard let url = Bundle(for: MarcaBundle.self).url(forResource: nombre, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(nombre).json"])
        }
        return url
    }
}

/// Servidor falso basado en URLProtocol. Cada instancia se identifica por una cabecera
/// propia, así que los tests pueden ejecutarse en paralelo sin pisarse.
final class ServidorMock: @unchecked Sendable {
    typealias Manejador = @Sendable (URLRequest) throws -> (Int, Data)

    let id = UUID().uuidString
    let session: URLSession
    private let lock = NSLock()
    private var _peticiones: [URLRequest] = []
    private let manejador: Manejador

    init(_ manejador: @escaping Manejador) {
        self.manejador = manejador
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProtocoloMock.self]
        config.httpAdditionalHeaders = [ProtocoloMock.cabecera: id]
        session = URLSession(configuration: config)
        ProtocoloMock.registrar(self)
    }

    deinit { ProtocoloMock.quitar(id) }

    var peticiones: [URLRequest] { lock.withLock { _peticiones } }

    fileprivate func responder(a peticion: URLRequest) throws -> (Int, Data) {
        lock.withLock { _peticiones.append(peticion) }
        return try manejador(peticion)
    }

    /// Responde siempre con este estado y este fixture (o este JSON literal).
    static func fijo(_ status: Int, fixture: String) throws -> ServidorMock {
        let datos = try Fixture.datos(fixture)
        return ServidorMock { _ in (status, datos) }
    }
}

final class ProtocoloMock: URLProtocol, @unchecked Sendable {
    static let cabecera = "X-Servidor-Mock"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var servidores: [String: ServidorMock] = [:]

    static func registrar(_ s: ServidorMock) { lock.withLock { servidores[s.id] = s } }
    static func quitar(_ id: String) { lock.withLock { _ = servidores.removeValue(forKey: id) } }
    private static func servidor(_ id: String?) -> ServidorMock? { lock.withLock { id.flatMap { servidores[$0] } } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var peticion = request
        // URLSession entrega el cuerpo como stream a los URLProtocol: se reconstruye.
        if peticion.httpBody == nil, let stream = peticion.httpBodyStream {
            peticion.httpBody = Data(leyendo: stream)
        }
        guard let servidor = Self.servidor(peticion.value(forHTTPHeaderField: Self.cabecera)) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (status, datos) = try servidor.responder(a: peticion)
            let respuesta = HTTPURLResponse(url: peticion.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                            headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: respuesta, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: datos)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension Data {
    init(leyendo stream: InputStream) {
        self.init()
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            guard n > 0 else { break }
            append(buffer, count: n)
        }
    }
}

let urlBase = URL(string: "http://api.test")!

/// Normaliza los espacios duros que usan los formatos de es_ES ("1.234,56 €").
func sinEspaciosDuros(_ s: String) -> String {
    s.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
}
