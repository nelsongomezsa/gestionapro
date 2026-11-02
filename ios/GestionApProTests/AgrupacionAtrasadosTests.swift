import Foundation
import Testing
@testable import GestionApPro

/// Fase 2: cobros atrasados y listas agrupadas por piso.
@MainActor
struct AgrupacionAtrasadosTests {
    private let json = """
    [{"idContrato":7,"inquilino":{"id":3,"nombre":"Ana Ruiz","dni":"1A","telefono":null,"email":null},
      "numeroHabitacion":2,"piso":{"id":1,"direccion":"Calle B","ciudad":"Madrid"},"mes":"2026-09",
      "nombreMes":"septiembre 2026","importe":450.00,"diasRetraso":58,"contratoActivo":true}]
    """

    @Test func atrasado_seDecodificaYPoneLaFechaEnElMesQueSalda() throws {
        let a = try JSONCoding.decoder().decode([CobroAtrasado].self, from: Data(json.utf8)).first!
        #expect(a.id == "7-2026-09")
        #expect(a.mesTitulo == "Septiembre 2026")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let f = try #require(a.fechaParaSaldar)
        #expect(cal.component(.month, from: f) == 9)
        #expect(cal.component(.day, from: f) == 30)
    }

    @Test func alertaDeAtrasados_abreSuLista() {
        let a = Alerta(tipo: "COBROS_ATRASADOS", titulo: "3 cobros atrasados · 1.350,00 €", mensaje: "", tono: "negativo")
        #expect(ResumenesInicio.destino(de: a) == .atrasados)
        #expect(a.tonoVisual == .negativo)
    }

    @Test func agrupar_porDireccionConSinPisoAlFinal_yConservaElOrden() throws {
        let inquilinos = try Fixture.decodificar([Inquilino].self, de: "inquilinos")
        let grupos = AgrupadorPiso.agrupar(inquilinos) { $0.contratoActivo?.piso }
        let direcciones = grupos.compactMap { $0.piso?.direccion }
        #expect(direcciones == direcciones.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        #expect(grupos.reduce(0) { $0 + $1.elementos.count } == inquilinos.count)
        if let sin = grupos.firstIndex(where: { $0.piso == nil }) { #expect(sin == grupos.count - 1) }
        // Dentro de cada grupo, el orden original.
        for g in grupos {
            let ids = g.elementos.map(\.id)
            #expect(ids == inquilinos.filter { e in ids.contains(e.id) }.map(\.id))
        }
    }

    @Test func resumenes_porPiso() throws {
        let contratos = try Fixture.decodificar([Contrato].self, de: "contratos")
        let uno = Array(contratos.prefix(1))
        #expect(ResumenPorPiso.contratos(uno).hasPrefix("1 contrato · "))
        let incidencias = try Fixture.decodificar([Incidencia].self, de: "incidencias")
        #expect(ResumenPorPiso.incidencias(incidencias).hasPrefix("\(incidencias.count) incidencias"))
        let pagos = try Fixture.decodificar([Pago].self, de: "pagos")
        let texto = ResumenPorPiso.cobros(pagos.map(ElementoCobro.pago))
        #expect(texto.hasPrefix("Cobrado "))
        #expect(!texto.contains("pendiente"))
    }
}
