import Foundation
import PDFKit
import Testing
@testable import GestionApPro

@Suite("Incidencias y detalle de piso")
struct IncidenciasPisoTests {

    @Test func incidencias() throws {
        let lista = try Fixture.decodificar([Incidencia].self, de: "incidencias")
        #expect(lista.count == 20)
        #expect(Set(lista.map(\.estado)) == [.pendiente, .enProceso, .resuelta])
        #expect(lista.allSatisfy { $0.dias >= 0 })
    }

    @Test func flujoDeEstados_comoElEscritorio() {
        #expect(EstadoIncidencia.pendiente.siguiente == .enProceso)
        #expect(EstadoIncidencia.enProceso.siguiente == .resuelta)
        #expect(EstadoIncidencia.resuelta.siguiente == nil)
        #expect(EstadoIncidencia.resuelta.accionSiguiente == nil)
        #expect(EstadoIncidencia.enProceso.rawValue == "en_proceso")
    }

    @Test func avanzarSinEstado_enviaCuerpoVacio() async throws {
        let servidor = try ServidorMock.fijo(200, fixture: "incidencias")
        let cliente = APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))
        // La respuesta no es una incidencia suelta: solo interesa la petición.
        _ = try? await cliente.enviar(.cambiarEstado(incidencia: 7))
        let p = try #require(servidor.peticiones.first)
        #expect(p.httpMethod == "PATCH")
        #expect(p.url?.path() == "/api/incidencias/7/estado")
        #expect(p.httpBody.map { String(decoding: $0, as: UTF8.self) } == "{}", "Sin estado la API avanza un paso")
    }

    @Test func ingresosDeUnPiso() throws {
        let meses = try Fixture.decodificar([ImporteMes].self, de: "ingresos-piso")
        #expect(meses.count == 12)
        #expect(meses.last?.etiqueta == "oct")
    }

    @Test func datosFinancieros_seCopianDelPisoParaEditar() throws {
        let piso = try #require(try Fixture.decodificar([Piso].self, de: "pisos").first { $0.id == 6 })
        let d = DatosFinancierosRequest(piso.datosFinancieros)
        #expect(d.precioCompra == Decimal(string: "85000"))
        #expect(d.tieneHipoteca)
        #expect(d.plazoAnos == 20)
        let json = try #require(try JSONSerialization.jsonObject(with: JSONCoding.encoder().encode(d)) as? [String: Any])
        #expect(json["importeHipoteca"] as? Double == 55000)
        #expect(json["cuotaMensualHipoteca"] == nil, "La cuota la calcula la API")
    }

    @Test func pdfPorSecciones() throws {
        let datos = GeneradorPDF.secciones(titulo: "Análisis de rentabilidad", [
            ("Rentabilidad", [("Rentabilidad bruta", "7,21 %"), ("Cash flow mensual", "364,51 €")]),
            ("Financiación", [("Hipoteca", "160.000,00 €")]),
        ])
        let doc = try #require(PDFDocument(data: datos))
        let texto = try #require(doc.string)
        #expect(texto.contains("Análisis de rentabilidad"))
        #expect(texto.contains("160.000,00 €"))
        #expect(texto.contains("FINANCIACIÓN"))
    }
}
