import Foundation
import Testing
@testable import GestionApPro

@Suite("Perfil, usuarios, búsqueda y registro")
struct PerfilUsuariosTests {

    @Test func usuarios() throws {
        let lista = try Fixture.decodificar([UsuarioAdmin].self, de: "usuarios")
        #expect(lista.count == 4)
        #expect(lista.first?.rol == .admin)
        #expect(lista.contains { $0.rol == .inquilino })
    }

    @Test func busqueda() throws {
        let r = try Fixture.decodificar(ResultadosBusqueda.self, de: "busqueda")
        #expect(!r.vacio)
        #expect(r.pisos.isEmpty)
        #expect(r.inquilinos.count == 7)
        #expect(r.contratos.allSatisfy { $0.subtitulo?.isEmpty == false })
    }

    @Test func buscar_enviaElTexto() async throws {
        let servidor = try ServidorMock.fijo(200, fixture: "busqueda")
        let cliente = APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))
        _ = try await cliente.enviar(.buscar("lucía"))
        let p = try #require(servidor.peticiones.first)
        let partes = try #require(p.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        #expect(partes.path == "/api/buscar")
        #expect(partes.queryItems?.first { $0.name == "q" }?.value == "lucía")
    }

    @Test func miActividad_pideSoloLaMia() async throws {
        let servidor = ServidorMock { _ in (200, Data("[]".utf8)) }
        let cliente = APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))
        let lista = try await cliente.enviar(.miActividad())
        #expect(lista.isEmpty)
        let url = try #require(servidor.peticiones.first?.url?.absoluteString)
        #expect(url.contains("soloMia=true"))
    }

    @Test func cambiarPassword_esPutSinRespuesta() async throws {
        let servidor = ServidorMock { _ in (204, Data()) }
        let cliente = APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))
        _ = try await cliente.enviar(.cambiarPassword(CambioPasswordRequest(actual: "vieja-123", nueva: "nueva-1234")))
        let p = try #require(servidor.peticiones.first)
        #expect(p.httpMethod == "PUT")
        #expect(p.url?.path() == "/api/me/password")
        let json = try #require(p.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: String] })
        #expect(json == ["actual": "vieja-123", "nueva": "nueva-1234"])
    }

    @Test func cambiarRol_enviaElCodigoDeLaAPI() async throws {
        let servidor = ServidorMock { _ in (200, Data(#"{"id":2,"nombre":"G","email":"g@x.com","rol":"ADMIN","activo":true}"#.utf8)) }
        let cliente = APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))
        let u = try await cliente.enviar(.cambiarRol(usuario: 2, a: .admin))
        #expect(u.rol == .admin)
        let p = try #require(servidor.peticiones.first)
        #expect(p.httpMethod == "PATCH")
        #expect(p.httpBody.map { String(decoding: $0, as: UTF8.self) } == #"{"rol":"ADMIN"}"#)
    }

    @Test func validarNuevaPassword() {
        #expect(CambiarPasswordView.validar(actual: "", nueva: "", repetida: "") == "")
        #expect(CambiarPasswordView.validar(actual: "a", nueva: "corta", repetida: "corta") != nil)
        #expect(CambiarPasswordView.validar(actual: "a", nueva: "larga-123", repetida: "otra-1234") == "Las contraseñas nuevas no coinciden")
        #expect(CambiarPasswordView.validar(actual: "a", nueva: "larga-123", repetida: "larga-123") == nil)
    }

    @Test @MainActor func registroDeInquilino_iniciaSesion() async throws {
        let login = try Fixture.datos("login")
        let servidor = ServidorMock { _ in (200, login) }
        let tokens = TokenStoreEnMemoria()
        let sesion = SesionStore(baseURL: urlBase, tokens: tokens, session: servidor.session)
        try await sesion.registrarInquilino(codigo: "K7M2-QX9P-4TBW", email: "a@b.com", password: "clave-segura")
        #expect(sesion.usuario != nil)
        #expect(tokens.leer() != nil)
        let p = try #require(servidor.peticiones.first)
        #expect(p.url?.path() == "/api/auth/register-inquilino")
        #expect(p.value(forHTTPHeaderField: "Authorization") == nil)
    }
}
