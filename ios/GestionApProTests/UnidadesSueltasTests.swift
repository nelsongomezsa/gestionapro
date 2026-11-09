import Foundation
import Testing
@testable import GestionApPro

/// Unidades sueltas: una sola plaza o un solo trastero como inmueble propio.
@MainActor
struct UnidadesSueltasTests {

    private func piso(id: Int = 1, tipo: String, numero: Int = 1, alquiladas: Int = 0, ingresos: Int = 0,
                      inversion: Int? = nil, cashFlow: Int = 0, bruta: Double? = nil) throws -> Piso {
        let metricas = inversion.map {
            #","metricas":{"inversionTotal":\#($0),"cuotaMensualHipoteca":0,"gastosAnuales":0,"capitalPropio":0,"plusvaliaLatente":0,"cashFlowMensual":\#(cashFlow),"rentabilidadBrutaPct":\#(bruta ?? 0)}"#
        } ?? ""
        return try JSONCoding.decoder().decode(Piso.self, from: Data("""
        {"id":\(id),"direccion":"A","tipo":"\(tipo)","ciudad":{"id":1,"nombre":"Madrid"},"numeroHabitaciones":\(numero),"idPropietario":1,
         "ocupacion":{"total":\(numero),"alquiladas":\(alquiladas),"disponibles":\(numero - alquiladas),"mantenimiento":0},"ingresosMensuales":\(ingresos)\(metricas)}
        """.utf8))
    }

    private func unidad(tipo: String, estado: String, extra: String = "") throws -> Habitacion {
        try JSONCoding.decoder().decode(Habitacion.self, from: Data("""
        {"id":7,"numero":3,"tipo":"\(tipo)","precio":90,"estado":"\(estado)",
         "piso":{"id":2,"direccion":"B","ciudad":"Madrid","tipo":"garajes"}\(extra)}
        """.utf8))
    }

    @Test func soloEsSueltaUnaUnidadQueNoEsVivienda() throws {
        #expect(try piso(tipo: "garajes").esUnidadSuelta)
        #expect(try piso(tipo: "trasteros").grupoSueltas == .trasteros)
        #expect(try piso(tipo: "garajes").grupoSueltas == .plazas)
        #expect(try !piso(tipo: "vivienda").esUnidadSuelta)
        #expect(try !piso(tipo: "garajes", numero: 8).esUnidadSuelta)
    }

    @Test func situacion_conElNombreOLaFecha() throws {
        let alquilada = try unidad(tipo: "plaza", estado: "alquilada", extra: #","inquilinoActual":{"id":1,"nombre":"Ana Ruiz"}"#)
        #expect(alquilada.situacionSuelta.contains("Alquilada a Ana Ruiz"))
        let trastero = try unidad(tipo: "trastero", estado: "alquilada", extra: #","inquilinoActual":{"id":1,"nombre":"Ana Ruiz"}"#)
        #expect(trastero.situacionSuelta.contains("Alquilado a Ana Ruiz"))
        let libre = try unidad(tipo: "plaza", estado: "disponible", extra: #","libreDesde":"2026-10-16""#)
        #expect(libre.situacionSuelta.hasPrefix("Libre desde"))
        #expect(try unidad(tipo: "plaza", estado: "disponible").situacionSuelta == "Libre")
    }

    @Test func altaSuelta_sinPasoDeUnidades_yUnaSolaUnidad() throws {
        let vm = NuevoPisoViewModel()
        vm.cambiarTipo(.garajes)
        vm.direccion = "Calle Mayor s/n"
        vm.idCiudad = 1
        #expect(!vm.puedeAvanzar(desde: .basicos), "Sin contestar si es suelta o edificio no avanza")

        vm.elegirModo(.suelta)
        #expect(vm.pasos == [.basicos, .financieros])
        #expect(vm.numeroHabitaciones == 1 && vm.conDatosFinancieros)
        #expect(!vm.puedeAvanzar(desde: .basicos), "Falta el precio")

        let h = try #require(vm.habitaciones.first)
        vm.cambiarNumeroHabitacion(h.id, 27)
        vm.cambiarPrecio(h.id, 95)
        vm.metros = 12
        vm.planta = "-2"
        #expect(vm.puedeAvanzar(desde: .basicos))
        #expect(vm.pasoVecino(1) == .financieros)

        let req = vm.peticion(idCiudad: 1)
        #expect(req.numeroHabitaciones == 1 && req.habitaciones?.count == 1)
        let u = try #require(req.habitaciones?.first)
        #expect(u.numero == 27 && u.tipo == .plaza && u.planta == "-2")
    }

    @Test func altaEdificio_conservaLosTresPasos_yVolverAVivienda_quitaLaPregunta() {
        let vm = NuevoPisoViewModel()
        vm.cambiarTipo(.trasteros)
        vm.elegirModo(.edificio)
        #expect(vm.pasos == NuevoPisoViewModel.Paso.allCases && vm.numeroHabitaciones == 10)
        vm.elegirModo(.suelta)
        #expect(vm.numeroHabitaciones == 1)
        vm.cambiarTipo(.vivienda)
        #expect(vm.modo == nil && vm.pasos == NuevoPisoViewModel.Paso.allCases)
    }

    @Test func totales_ponderanPorLoInvertido() throws {
        let a = try piso(id: 1, tipo: "garajes", alquiladas: 1, ingresos: 100, inversion: 10_000, cashFlow: 60, bruta: 12)
        let b = try piso(id: 2, tipo: "trasteros", ingresos: 0, inversion: 30_000, cashFlow: -20, bruta: 0)
        let t = TotalesSueltas([a, b])
        #expect(t.cashFlowMensual == 40)
        #expect(abs((t.rentabilidadBrutaPct ?? 0) - 3) < 0.0001, "1.200 € al año sobre 40.000 €, no la media de 12 y 0")
        #expect(TotalesSueltas([try piso(tipo: "garajes")]).rentabilidadBrutaPct == nil)
    }

    @Test func ranking_deMejorAPeor_yLasSinDatosAlFinal() throws {
        let a = try piso(id: 1, tipo: "garajes", inversion: 1000, cashFlow: 10, bruta: 5)
        let b = try piso(id: 2, tipo: "garajes", inversion: 1000, cashFlow: 50, bruta: 3)
        let c = try piso(id: 3, tipo: "trasteros")
        #expect(RankingSueltas.ordenar([c, b, a], por: .rentabilidad).map(\.id) == [1, 2, 3])
        #expect(RankingSueltas.ordenar([c, a, b], por: .cashFlow).map(\.id) == [2, 1, 3])
    }

    @Test func filtroPorGrupo_ySusTotales_excluyenElFiltroPorTipo() throws {
        let vm = PisosViewModel()
        vm.tipo = .garajes
        vm.grupo = .trasteros
        #expect(vm.tipo == nil)
        vm.tipo = .vivienda
        #expect(vm.grupo == nil)
    }
}
