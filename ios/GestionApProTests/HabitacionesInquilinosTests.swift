import Foundation
import PDFKit
import Testing
@testable import GestionApPro

@Suite("Habitaciones e inquilinos: decodificación")
struct HabitacionesInquilinosDecodificacionTests {

    @Test func habitacionesDeUnPiso() throws {
        let lista = try Fixture.decodificar([Habitacion].self, de: "habitaciones")
        #expect(lista.count == 5)
        let primera = try #require(lista.first)
        #expect(primera.estado == .alquilada)
        #expect(primera.piso.direccion == "Calle Mayor 15, 3º A")
        #expect(primera.inquilinoActual != nil)
        #expect(primera.diasAlquilada != nil)
        let libre = try #require(lista.last)
        #expect(libre.estado == .disponible)
        #expect(libre.inquilinoActual == nil)
        #expect(libre.diasAlquilada == nil)
    }

    @Test func listaDeInquilinos_sinContratosNiPagosDetallados() throws {
        let lista = try Fixture.decodificar([Inquilino].self, de: "inquilinos")
        #expect(lista.count == 25)
        #expect(lista.allSatisfy { $0.contratos.isEmpty && $0.pagos.isEmpty })
        #expect(lista.contains { $0.contratoActivo != nil })
    }

    @Test func fichaDeInquilino_conContratosYPagos() throws {
        let i = try Fixture.decodificar(Inquilino.self, de: "inquilino")
        #expect(!i.contratos.isEmpty)
        #expect(!i.pagos.isEmpty)
        let activo = try #require(i.contratoActivo)
        #expect(activo.activo)
        #expect([.normal, .proximo, .critico].contains(activo.vencimiento))
        #expect(i.pagos.first.map { [.transferencia, .efectivo, .domiciliacion].contains($0.metodoPago) } == true)
    }

    @Test func qrDePago() throws {
        let qr = try Fixture.decodificar(QrPago.self, de: "qr")
        #expect(qr.payload.hasPrefix("BCD\n002\n1\nSCT\n"))
        #expect(qr.iban == "ES91 2100 0418 4502 0005 1332")
        #expect(qr.concepto.hasSuffix("octubre 2026"))
    }
}

@Suite("APIClient: consultas y respuestas vacías")
struct APIClientConsultasTests {

    @Test func parametrosDeConsulta_seOmitenLosNulos() async throws {
        let servidor = try ServidorMock.fijo(200, fixture: "habitaciones")
        let cliente = APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))

        _ = try await cliente.enviar(.habitaciones(piso: 1))
        _ = try await cliente.enviar(.habitaciones(piso: 2, estado: .mantenimiento))

        let urls = servidor.peticiones.compactMap { $0.url?.absoluteString }
        #expect(urls == ["http://api.test/api/habitaciones?piso=1",
                         "http://api.test/api/habitaciones?piso=2&estado=mantenimiento"])
    }

    @Test func borrar_204SinCuerpo() async throws {
        let servidor = ServidorMock { _ in (204, Data()) }
        let cliente = APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))

        _ = try await cliente.enviar(.borrarHabitacion(id: 7))

        #expect(servidor.peticiones.first?.httpMethod == "DELETE")
        #expect(servidor.peticiones.first?.url?.path() == "/api/habitaciones/7")
    }

    @Test func patchPerfil_soloEnviaLoIndicado() async throws {
        let servidor = try ServidorMock.fijo(200, fixture: "me")
        let cliente = APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))

        _ = try await cliente.enviar(.actualizarPerfil(ActualizarPerfilRequest(iban: "ES91 2100")))

        let cuerpo = try #require(servidor.peticiones.first?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: cuerpo) as? [String: Any])
        #expect(json.keys.sorted() == ["iban"], "Los nil no se envían: PATCH no debe borrar nombre ni email")
        #expect(servidor.peticiones.first?.httpMethod == "PATCH")
    }
}

@Suite("Utilidades de la fase 4B")
struct UtilidadesFase4BTests {

    @Test func qr_generaUnaImagenCuadrada() throws {
        let qr = try Fixture.decodificar(QrPago.self, de: "qr")
        let imagen = try #require(CodigoQR.imagen(de: qr.payload, lado: 300))
        #expect(imagen.size.width == imagen.size.height)
        #expect(imagen.size.width >= 290)
    }

    @Test func whatsApp_anadeElPrefijoEspanolA9Cifras() {
        #expect(Contacto.whatsApp("633 456 789")?.absoluteString == "https://wa.me/34633456789")
        #expect(Contacto.whatsApp("+44 7700 900123")?.absoluteString == "https://wa.me/447700900123")
        #expect(Contacto.llamada("633 456 789")?.absoluteString == "tel:633456789")
        #expect(Contacto.email("ana@example.com")?.absoluteString == "mailto:ana@example.com")
    }

    @Test func vCard() {
        let v = Contacto.vCard(nombre: "Ana", apellidos: "López", telefono: "600 111 222", email: nil)
        #expect(v.contains("FN:Ana López"))
        #expect(v.contains("TEL;TYPE=CELL:600111222"))
        #expect(!v.contains("EMAIL"))
    }

    @Test func pdfDeTabla_variasPaginas() throws {
        let filas = (1...120).map { ["Hab. \($0)", "450,00 €", "Alquilada"] }
        let datos = GeneradorPDF.tabla(titulo: "Habitaciones", columnas: [
            .init(titulo: "Hab.", peso: 1), .init(titulo: "Precio", peso: 1), .init(titulo: "Estado", peso: 1),
        ], filas: filas)
        #expect(datos.prefix(5) == Data("%PDF-".utf8))
        let documento = try #require(PDFDocument(data: datos))
        #expect(documento.pageCount > 1, "120 filas no caben en una página A4")
        #expect(documento.string?.contains("Hab. 120") == true)
    }
}
