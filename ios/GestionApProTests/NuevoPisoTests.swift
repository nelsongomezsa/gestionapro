import Foundation
import Testing
@testable import GestionApPro

/// Alta de piso por pasos: habitaciones, validación en directo y petición a la API.
@MainActor
struct NuevoPisoTests {
    private func cliente(_ s: ServidorMock) -> APIClient {
        APIClient(baseURL: URL(string: "http://localhost:8080")!, session: s.session, tokens: TokenStoreEnMemoria(token: "t"))
    }

    @Test func habitaciones_seCreanSolas_yConservanLoEditado() {
        let vm = NuevoPisoViewModel()
        #expect(vm.habitaciones.map(\.numero) == [1, 2, 3])
        vm.cambiarPrecio(vm.habitaciones[0].id, 450)
        vm.cambiarNumero(5)
        #expect(vm.habitaciones.map(\.numero) == [1, 2, 3, 4, 5])
        #expect(vm.habitaciones[0].precio == 450)
        vm.cambiarNumero(2)
        #expect(vm.habitaciones.count == 2 && vm.habitaciones[0].precio == 450)
        vm.cambiarNumero(0)
        #expect(vm.numeroHabitaciones == 1)
        vm.cambiarNumero(99)
        #expect(vm.numeroHabitaciones == NuevoPisoViewModel.maxHabitaciones)
        vm.aplicarATodas(380)
        #expect(vm.habitaciones.allSatisfy { $0.precio == 380 })
    }

    @Test func validacionEnDirecto() {
        let vm = NuevoPisoViewModel()
        #expect(vm.errorDireccion != nil)
        #expect(!vm.puedeAvanzar(desde: .basicos))
        vm.direccion = "  Calle Nueva 5, 1º "
        vm.idCiudad = 1
        #expect(vm.puedeAvanzar(desde: .basicos))
        vm.otraCiudad = true
        vm.nuevaCiudad = "<x>"
        #expect(vm.errorCiudad != nil)
        vm.nuevaCiudad = "Málaga"
        #expect(vm.errorCiudad == nil)
        // Habitaciones: precio > 0 y números distintos.
        #expect(!vm.puedeAvanzar(desde: .habitaciones))
        vm.aplicarATodas(400)
        #expect(vm.puedeAvanzar(desde: .habitaciones))
        vm.cambiarNumeroHabitacion(vm.habitaciones[1].id, 1)
        #expect(vm.errorNumero(vm.habitaciones[0]) != nil)
        #expect(!vm.puedeGuardar)
        vm.cambiarNumeroHabitacion(vm.habitaciones[1].id, 2)
        vm.cambiarPrecio(vm.habitaciones[2].id, 100_000)
        #expect(vm.errorPrecio(vm.habitaciones[2]) != nil)
        vm.cambiarPrecio(vm.habitaciones[2].id, 450.5)
        #expect(vm.puedeGuardar)
    }

    @Test func guardar_daDeAltaLaCiudadYElPisoConSusHabitaciones() async throws {
        let piso = try Fixture.decodificar([Piso].self, de: "pisos").first!
        let pisoJSON = try JSONSerialization.data(withJSONObject: (JSONSerialization.jsonObject(with: Fixture.datos("pisos")) as! [Any]).first!)
        let servidor = ServidorMock { p in
            p.url?.path == "/api/ciudades" ? (201, Data(#"{"id":9,"nombre":"Málaga"}"#.utf8)) : (201, pisoJSON)
        }
        let vm = NuevoPisoViewModel()
        vm.direccion = "Calle Larios 3, 2º"
        vm.otraCiudad = true
        vm.nuevaCiudad = "Málaga"
        vm.cambiarNumero(2)
        vm.aplicarATodas(425.5)
        let creado = await vm.guardar(con: cliente(servidor))
        #expect(creado?.id == piso.id)
        let rutas = servidor.peticiones.map { "\($0.httpMethod ?? "") \($0.url?.path ?? "")" }
        #expect(rutas == ["POST /api/ciudades", "POST /api/pisos"])
        let datos = try #require(servidor.peticiones[1].httpBody)
        let cuerpo = try #require(JSONSerialization.jsonObject(with: datos) as? [String: Any])
        #expect(cuerpo["idCiudad"] as? Int == 9)
        #expect(cuerpo["numeroHabitaciones"] as? Int == 2)
        #expect(cuerpo["datosFinancieros"] == nil)
        let habs = try #require(cuerpo["habitaciones"] as? [[String: Any]])
        #expect(habs.count == 2 && (habs[1]["numero"] as? Int) == 2)
        #expect((habs[0]["precio"] as? NSNumber)?.doubleValue == 425.5)
    }

    @Test func guardar_conDatosNoValidos_noLlamaALaAPI() async {
        let servidor = ServidorMock { _ in (500, Data()) }
        let vm = NuevoPisoViewModel()
        #expect(await vm.guardar(con: cliente(servidor)) == nil)
        #expect(servidor.peticiones.isEmpty)
    }
}
