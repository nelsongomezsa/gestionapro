import Foundation
import Testing
@testable import GestionApPro

/// Nombres de mes con el idioma de la app y la tarjeta "Cobrado" de Inicio por meses.
@MainActor
struct MesesHeroeTests {
    private let en = Locale(identifier: "en_ES")
    private let es = Locale(identifier: "es_ES")

    @Test func meses_enElIdiomaDeLaApp() {
        #expect(Formato.mes("2026-11", en: en) == "November 2026")
        #expect(Formato.mes("2026-11", corto: true, en: en) == "Nov")
        #expect(Formato.mesEnFrase("2026-11", en: en) == "November 2026")
        #expect(Formato.mes("2026-11", en: es) == "Noviembre 2026")
        #expect(Formato.mes("2026-09", corto: true, en: es)?.hasPrefix("sep") == true)
        #expect(Formato.mesEnFrase("2026-11", en: es) == "noviembre 2026")
        #expect(Formato.mes("2026-13") == nil)
    }

    @Test func losMesesDeLaAPI_seRehacenDesdeAaaamm() throws {
        // La API los manda en español: la app no usa ese texto.
        let i = try JSONCoding.decoder().decode(ImporteMes.self, from: Data(#"{"mes":"2026-10","etiqueta":"XX","importe":5}"#.utf8))
        #expect(i.etiqueta == Formato.mes("2026-10", corto: true))
        let r = try JSONCoding.decoder().decode(ResumenPagos.self, from: Data("""
            {"mes":"2026-10","nombreMes":"texto de la API","esperado":1,"cobrado":1,"pendiente":0,"numeroPagos":1,"pendientes":[]}
            """.utf8))
        #expect(r.nombreMes == Formato.mesEnFrase("2026-10"))
    }

    private func cliente(_ s: ServidorMock) -> APIClient {
        APIClient(baseURL: URL(string: "http://localhost:8080")!, session: s.session, tokens: TokenStoreEnMemoria(token: "t"))
    }

    @Test func tarjeta_usaElResumenDeCobros_yNoPasaDeHoy() async throws {
        let panel = try Fixture.datos("dashboard")
        let resumen = try Fixture.datos("resumen-pagos")
        let servidor = ServidorMock { p in
            switch p.url?.path {
            case "/api/notificaciones/no-leidas": (200, Data(#"{"total":0}"#.utf8))
            case "/api/pagos/resumen": (200, resumen)
            default: (200, panel)
            }
        }
        let vm = InicioViewModel()
        await vm.cargar(con: cliente(servidor))
        #expect(vm.resumenHeroe != nil)
        #expect(servidor.peticiones.contains { $0.url?.query?.contains("mes=\(Mes.actual.texto)") == true })

        await vm.cambiarMesHeroe(Mes.actual.siguiente, con: cliente(servidor))
        #expect(vm.mesHeroe == .actual)
        await vm.cambiarMesHeroe(Mes.actual.anterior, con: cliente(servidor))
        #expect(vm.mesHeroe == Mes.actual.anterior)
        #expect(servidor.peticiones.contains { $0.url?.query?.contains("mes=\(Mes.actual.anterior.texto)") == true })
    }

    @Test func irACobros_guardaElMesPedido() {
        let ir = IrACobros()
        ir.mes = Mes.actual.anterior
        #expect(ir.mes == Mes.actual.anterior)
    }
}

struct RedondeoTests {
    @Test func porcentaje_redondeaComoLaAPI() {
        #expect(sinEspaciosDuros(Formato.porcentaje(1.625)) == sinEspaciosDuros("1,63 %"))
        #expect(sinEspaciosDuros(Formato.porcentaje(9.8052)) == sinEspaciosDuros("9,81 %"))
        #expect(sinEspaciosDuros(Formato.porcentaje(-3.5209)) == sinEspaciosDuros("-3,52 %"))
        #expect(Formato.porcentaje(Double?.none) == "—")
    }
}
