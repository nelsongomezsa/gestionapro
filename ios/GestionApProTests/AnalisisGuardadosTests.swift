import Foundation
import Testing
@testable import GestionApPro

/// Fase 4: análisis de inversión guardados y su comparación.
@MainActor
struct AnalisisGuardadosTests {
    private func respuesta(id: Int, nombre: String, neta: Double, precio: Double = 200000) -> String {
        """
        {"id":\(id),"nombre":"\(nombre)","idPiso":null,"fecha":"2026-11-02T10:00:00+01:00",
         "entrada":{"comunidad":"Madrid","precioCompra":\(precio),"alquilerMensual":1400.0,"plazoAnos":25,"porcentajeFinanciado":80.0,"tipoInteresPct":3.0},
         "resultado":{"itpPct":6,"itpImporte":12000,"totalCompra":230000,"gastosMensuales":200,"gastosAnuales":2400,"alquilerAnual":16800,
                      "hipoteca":160000,"capitalAportado":70000,"cuotaMensual":758.75,"interesesMensualesPromedio":300,"amortizacionMensualPromedio":458,
                      "rentabilidadBrutaPct":7.3,"rentabilidadNetaPct":\(neta),"cashFlowMensual":441.25,"cashFlowAnual":5295,
                      "aniosRecuperacion":13.2,"plusvalia5Anios":null,"plusvalia10Anios":null}}
        """
    }

    @Test func guardado_seDecodifica_conOpcionalesAusentesComoCero() throws {
        let a = try JSONCoding.decoder().decode(AnalisisGuardado.self, from: Data(respuesta(id: 1, nombre: "Piso A", neta: 6.2).utf8))
        #expect(a.entrada.reforma == 0)
        #expect(a.entrada.plazoAnos == 25)
        #expect(a.resultado?.plusvalia10Anios == nil)
    }

    @Test func mejorDeCadaFila() {
        #expect(ComparacionAnalisis.mejor([5, 7, 6], mayorEsMejor: true) == 1)
        #expect(ComparacionAnalisis.mejor([12, 9, nil], mayorEsMejor: false) == 1)
        #expect(ComparacionAnalisis.mejor([4, 4], mayorEsMejor: true) == nil)
        #expect(ComparacionAnalisis.mejor([4, nil], mayorEsMejor: true) == nil)
        #expect(ComparacionAnalisis.mejor([1, 2], mayorEsMejor: nil) == nil)
        #expect(ComparacionAnalisis.grupos.flatMap(\.filas).count == 11)
    }

    @Test func guardar_creaYDespuesActualiza_conPisoDeOrigen() async throws {
        let primera = respuesta(id: 7, nombre: "Calle Mayor", neta: 6.2)
        let servidor = ServidorMock { p in (p.httpMethod == "POST" ? 201 : 200, Data(primera.utf8)) }
        let api = APIClient(baseURL: URL(string: "http://localhost:8080")!, session: servidor.session,
                            tokens: TokenStoreEnMemoria(token: "t"))
        let vm = CalculadoraViewModel()
        vm.idPiso = 3
        #expect(await vm.guardar(nombre: "   ", comoNuevo: true, con: api) == false)
        #expect(await vm.guardar(nombre: " Calle Mayor ", comoNuevo: true, con: api))
        #expect(vm.guardado?.id == 7)
        #expect(await vm.guardar(nombre: "Calle Mayor", comoNuevo: false, con: api))
        let metodos = servidor.peticiones.map { "\($0.httpMethod ?? "") \($0.url?.path ?? "")" }
        #expect(metodos == ["POST /api/analisis-inversion", "PUT /api/analisis-inversion/7"])
        let cuerpo = try JSONSerialization.jsonObject(with: #require(servidor.peticiones[0].httpBody)) as? [String: Any]
        #expect(cuerpo?["nombre"] as? String == "Calle Mayor")
        #expect(cuerpo?["idPiso"] as? Int == 3)
    }

    @Test func nombrePorDefecto_llevaLaFecha() {
        #expect(CalculadoraView.nombrePorDefecto().hasPrefix("Análisis del "))
    }
}
