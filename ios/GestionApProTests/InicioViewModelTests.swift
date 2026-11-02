import Foundation
import Testing
@testable import GestionApPro

@MainActor
struct InicioViewModelTests {
    private let urlBase = URL(string: "http://localhost:8080")!

    private func cliente(_ servidor: ServidorMock) -> APIClient {
        APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))
    }

    @Test func cargar_traePanelYNoLeidas() async throws {
        let panel = try Fixture.datos("dashboard")
        let servidor = ServidorMock { p in
            p.url?.path == "/api/notificaciones/no-leidas" ? (200, Data(#"{"total":3}"#.utf8)) : (200, panel)
        }
        let vm = InicioViewModel()

        let d = await vm.cargar(con: cliente(servidor))

        #expect(d != nil)
        #expect(vm.estado.valor != nil)
        #expect(vm.noLeidas == 3)
        #expect(vm.error == nil)
    }

    @Test func cargar_conError_laPrimeraVezMuestraErrorYDespuesAviso() async throws {
        let servidor = ServidorMock { _ in (500, Data()) }
        let vm = InicioViewModel()

        await vm.cargar(con: cliente(servidor))
        if case .error = vm.estado {} else { Issue.record("Debía quedar en error") }
    }

    @Test func saludo_usaElPrimerNombre() {
        #expect(InicioViewModel.saludo(nombre: "Ana María López") == "Hola, Ana")
        #expect(InicioViewModel.saludo(nombre: nil) == "Inicio")
    }
}
