import Foundation
import Testing
@testable import GestionApPro

/// APIClient contra un servidor falso (URLProtocol).
@Suite("APIClient")
struct APIClientTests {

    /// Cuenta cuántas veces se avisó de un 401.
    final class Contador: @unchecked Sendable {
        private let lock = NSLock()
        private var n = 0
        func sumar() { lock.withLock { n += 1 } }
        var valor: Int { lock.withLock { n } }
    }

    private func cliente(_ servidor: ServidorMock, token: String? = "tok-123", contador: Contador = Contador()) -> APIClient {
        APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: token),
                  alNoAutorizado: { contador.sumar() })
    }

    @Test func get_anadeElTokenYDecodifica() async throws {
        let servidor = try ServidorMock.fijo(200, fixture: "pisos")
        let pisos = try await cliente(servidor).enviar(.pisos)

        #expect(pisos.count == 8)
        let p = try #require(servidor.peticiones.first)
        #expect(p.url?.absoluteString == "http://api.test/api/pisos")
        #expect(p.httpMethod == "GET")
        #expect(p.value(forHTTPHeaderField: "Authorization") == "Bearer tok-123")
        #expect(p.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func post_enviaElCuerpoJSON() async throws {
        let servidor = try ServidorMock.fijo(200, fixture: "rentabilidad")
        var req = RentabilidadRequest(comunidad: "Madrid", precioCompra: 200_000, gastosNotariaRegistro: 0,
                                      gastosHipoteca: 0, reforma: 0, comisionCompra: 0, mobiliario: 0, ibiMensual: 0,
                                      segurosMensual: 0, comunidadMensual: 0, mantenimientoMensual: 0, vacioMensual: 0,
                                      alquilerMensual: 1_400, revalorizacionAnualPct: 3, porcentajeFinanciado: 80,
                                      plazoAnos: 25, tipoInteresPct: 3.2)
        req.reforma = 10_000

        _ = try await cliente(servidor).enviar(.rentabilidad(req))

        let p = try #require(servidor.peticiones.first)
        #expect(p.httpMethod == "POST")
        #expect(p.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let cuerpo = try #require(p.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: cuerpo) as? [String: Any])
        #expect(json["comunidad"] as? String == "Madrid")
        #expect(json["plazoAnos"] as? Int == 25)
        #expect(json["reforma"] as? Double == 10_000)
        #expect(json.count == 17, "Los 17 campos de RentabilidadRequest")
    }

    @Test func login_noEnviaTokenY401NoCierraSesion() async throws {
        let servidor = try ServidorMock.fijo(401, fixture: "error401")
        let contador = Contador()

        await #expect(throws: APIError.respuesta(status: 401, try Fixture.decodificar(ErrorAPI.self, de: "error401"))) {
            try await cliente(servidor, contador: contador).enviar(.login(email: "a@b.c", password: "x"))
        }
        #expect(servidor.peticiones.first?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(contador.valor == 0, "Credenciales malas no son una sesión caducada")
    }

    @Test func error401EnRutaAutenticada_avisaParaVolverAlLogin() async throws {
        let servidor = ServidorMock { _ in
            (401, Data(#"{"status":401,"codigo":"NO_AUTENTICADO","mensaje":"Falta el token"}"#.utf8))
        }
        let contador = Contador()

        do {
            _ = try await cliente(servidor, contador: contador).enviar(.me)
            Issue.record("Debía fallar")
        } catch {
            guard case let .noAutorizado(cuerpo) = error else { Issue.record("Error inesperado: \(error)"); return }
            #expect(cuerpo?.codigo == "NO_AUTENTICADO")
        }
        #expect(contador.valor == 1)
    }

    @Test func sinTokenGuardado_noLlegaAPedirYAvisa() async throws {
        let servidor = try ServidorMock.fijo(200, fixture: "me")
        let contador = Contador()

        await #expect(throws: APIError.noAutorizado(nil)) {
            try await cliente(servidor, token: nil, contador: contador).enviar(.me)
        }
        #expect(servidor.peticiones.isEmpty)
        #expect(contador.valor == 1)
    }

    @Test func error400_conservaElFormatoDeErrorDeLaAPI() async throws {
        let servidor = try ServidorMock.fijo(400, fixture: "error400")

        do {
            _ = try await cliente(servidor).enviar(.pisos)
            Issue.record("Debía fallar")
        } catch {
            #expect(error.codigo == "VALIDACION")
            let texto = try #require(error.errorDescription)
            #expect(texto.hasPrefix("Hay campos con valores no válidos"))
            #expect(texto.contains("• direccion: no debe estar vacío"))
        }
    }

    @Test func error500SinJSON_mensajeGenerico() async throws {
        let servidor = ServidorMock { _ in (500, Data("<html>Internal error</html>".utf8)) }

        await #expect(throws: APIError.respuesta(status: 500, nil)) {
            try await cliente(servidor).enviar(.pisos)
        }
        #expect(APIError.respuesta(status: 500, nil).errorDescription == "Error del servidor (código 500).")
    }

    @Test func servidorCaido_esSinConexion() async throws {
        let servidor = ServidorMock { _ in throw URLError(.cannotConnectToHost) }

        await #expect(throws: APIError.sinConexion) {
            try await cliente(servidor).enviar(.pisos)
        }
    }

    @Test func respuestaConFormatoInesperado_esErrorDeDecodificacion() async throws {
        let servidor = ServidorMock { _ in (200, Data(#"{"no":"es un piso"}"#.utf8)) }

        do {
            _ = try await cliente(servidor).enviar(.piso(id: 1))
            Issue.record("Debía fallar")
        } catch {
            guard case .decodificacion = error else { Issue.record("Error inesperado: \(error)"); return }
        }
    }
}

@Suite("Sesión")
@MainActor
struct SesionStoreTests {

    @Test func login_guardaElTokenYEntra() async throws {
        let tokens = TokenStoreEnMemoria()
        let servidor = try ServidorMock.fijo(200, fixture: "login")
        let sesion = SesionStore(baseURL: urlBase, tokens: tokens, session: servidor.session)

        try await sesion.iniciarSesion(email: "admin@gestionap.com", password: "x")

        #expect(tokens.leer() == "eyJhbGciOiJIUzM4NCJ9.ficticio-para-tests.firma")
        #expect(sesion.usuario?.rol == .admin)
    }

    @Test func restaurar_sinToken_vaAlLogin() async {
        let sesion = SesionStore(baseURL: urlBase, tokens: TokenStoreEnMemoria(), session: .shared)
        await sesion.restaurar()
        #expect(sesion.estado == .sinSesion)
    }

    @Test func restaurar_conTokenValido_entraSinPedirCredenciales() async throws {
        let servidor = try ServidorMock.fijo(200, fixture: "me")
        let sesion = SesionStore(baseURL: urlBase, tokens: TokenStoreEnMemoria(token: "t"), session: servidor.session)

        await sesion.restaurar()

        #expect(sesion.usuario?.email == "admin@gestionap.com")
    }

    @Test func tokenCaducado_cierraSesionBorraElTokenYAvisa() async throws {
        let tokens = TokenStoreEnMemoria(token: "caducado")
        let servidor = ServidorMock { _ in (401, Data(#"{"status":401,"codigo":"NO_AUTENTICADO","mensaje":"x"}"#.utf8)) }
        let sesion = SesionStore(baseURL: urlBase, tokens: tokens, session: servidor.session)

        await sesion.restaurar()

        #expect(sesion.estado == .sinSesion)
        #expect(tokens.leer() == nil)
        #expect(sesion.aviso == "Tu sesión ha caducado. Vuelve a iniciar sesión.")
    }

    @Test func sinConexionAlArrancar_noBorraElToken() async throws {
        let tokens = TokenStoreEnMemoria(token: "valido")
        let servidor = ServidorMock { _ in throw URLError(.cannotConnectToHost) }
        let sesion = SesionStore(baseURL: urlBase, tokens: tokens, session: servidor.session)

        await sesion.restaurar()

        guard case .errorAlRestaurar = sesion.estado else {
            Issue.record("Estado inesperado: \(sesion.estado)")
            return
        }
        #expect(tokens.leer() == "valido")
    }

    @Test func cerrarSesion_borraElToken() async throws {
        let tokens = TokenStoreEnMemoria(token: "t")
        let sesion = SesionStore(baseURL: urlBase, tokens: tokens, session: .shared)
        sesion.cerrarSesion()
        #expect(tokens.leer() == nil)
        #expect(sesion.estado == .sinSesion)
    }
}
