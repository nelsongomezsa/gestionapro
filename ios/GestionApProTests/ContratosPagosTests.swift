import Foundation
import Testing
@testable import GestionApPro

@Suite("Contratos y pagos")
struct ContratosPagosTests {

    @Test func contratosActivos() throws {
        let lista = try Fixture.decodificar([Contrato].self, de: "contratos")
        #expect(lista.count == 20)
        #expect(lista.allSatisfy { $0.activo })
        #expect(lista.allSatisfy { $0.diasRestantes >= 0 })
        #expect(Set(lista.map(\.vencimiento)).isSubset(of: [.normal, .proximo, .critico]))
        #expect(lista.contains { $0.vencimiento == .proximo }, "Los datos de demo tienen contratos que vencen este mes")
    }

    @Test func pagosDelMes() throws {
        let pagos = try Fixture.decodificar([Pago].self, de: "pagos")
        #expect(pagos.count == 10)
        // El número de recibo es opcional: los pagos del escritorio no lo tienen hasta pedirlo.
        #expect(pagos[0].recibo == "2026-0012")
        #expect(pagos[1].recibo == nil)
        let mes = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "Europe/Madrid")!, from: pagos[0].fechaPago)
        #expect((mes.year, mes.month) == (2026, 10))
        #expect(pagos.allSatisfy { $0.cantidad > 0 })
    }

    @Test func resumenDelMes_cuadra() throws {
        let r = try Fixture.decodificar(ResumenPagos.self, de: "resumen-pagos")
        #expect(r.nombreMes == "octubre 2026")
        #expect(r.pendientes.count == 10)
        #expect(r.pendientes.reduce(0) { $0 + $1.importe } == r.pendiente)
        #expect(r.esperado > r.cobrado)
    }

    @Test func mes_navegaYFormatea() {
        let oct = Mes(anio: 2026, numero: 10)
        #expect(oct.texto == "2026-10")
        #expect(oct.siguiente.siguiente.siguiente == Mes(anio: 2027, numero: 1))
        #expect(Mes(anio: 2027, numero: 1).anterior == Mes(anio: 2026, numero: 12))
        #expect(oct.nombre == "Octubre 2026")
        #expect(oct < oct.siguiente)
    }

    @Test func fechaAPI_enHoraDeMadrid() throws {
        // 23:30 en Madrid del 30 de octubre son las 22:30 UTC del mismo día...
        let tarde = try #require(ISO8601DateFormatter().date(from: "2026-10-30T22:30:00Z"))
        #expect(FechaAPI.texto(tarde) == "2026-10-30")
        // ...pero las 23:30 UTC ya son el 31 en Madrid.
        let noche = try #require(ISO8601DateFormatter().date(from: "2026-10-30T23:30:00Z"))
        #expect(FechaAPI.texto(noche) == "2026-10-31")
    }

    @Test func recordatorio_comoEnElEscritorio() throws {
        let c = try #require(try Fixture.decodificar([Contrato].self, de: "contratos").first)
        #expect(Recordatorio.asunto(c) == "Recordatorio de pago - \(c.inquilino.nombre)")
        let cuerpo = Recordatorio.cuerpo(c)
        #expect(cuerpo.hasPrefix("Estimado/a \(c.inquilino.nombre),"))
        #expect(cuerpo.contains("habitación \(c.habitacion.numero) en \(c.piso.direccion) está pendiente"))
    }
}

@Suite("APIClient: descargas")
struct APIClientDescargasTests {

    @Test func descargarPDF_devuelveLosBytesYPideJSONParaLosErrores() async throws {
        let pdf = Data("%PDF-1.7 prueba".utf8)
        let servidor = ServidorMock { _ in (200, pdf) }
        let cliente = APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))

        let datos = try await cliente.descargar(Rutas.pdfContrato(3))

        #expect(datos == pdf)
        let p = try #require(servidor.peticiones.first)
        #expect(p.url?.path() == "/api/contratos/3/pdf")
        #expect(p.value(forHTTPHeaderField: "Accept") == "application/pdf, application/json")
        #expect(p.value(forHTTPHeaderField: "Authorization") == "Bearer t")
    }

    @Test func descargarPDF_ajeno_404ConMensajeDeLaAPI() async throws {
        let servidor = ServidorMock { _ in
            (404, Data(#"{"status":404,"codigo":"NO_ENCONTRADO","mensaje":"Contrato no encontrado"}"#.utf8))
        }
        let cliente = APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))

        do {
            _ = try await cliente.descargar(Rutas.pdfContrato(99))
            Issue.record("Debía fallar")
        } catch {
            #expect(error.codigo == "NO_ENCONTRADO")
            #expect(error.errorDescription == "Contrato no encontrado")
        }
    }

    @Test("Fianza devuelta en parte: estado, retenido y nada pendiente")
    func fianza() throws {
        let f = try Fixture.decodificar(Fianza.self, de: "fianza")
        #expect(f.estado == .devueltaParcial)
        #expect(f.estado.nombre == "Devuelta en parte")
        #expect(f.retenido == 100)
        #expect(f.pendienteDevolver == 0)
        #expect(f.fechaDevolucion != nil)
        #expect(f.notas == nil)
    }

    @Test("Propuesta de actualización de renta con el IRAV")
    func propuestaRenta() throws {
        let p = try Fixture.decodificar(PropuestaRenta.self, de: "propuesta-renta")
        #expect(p.debida)
        #expect(p.indice == .irav)
        #expect(p.porcentaje == Decimal(string: "2.54"))
        #expect(p.rentaNueva == Decimal(string: "512.7"))
        #expect(nombreMes(p.periodoIndice) == "septiembre de 2026")
        #expect(nombreMes(nil) == nil)
    }
}
