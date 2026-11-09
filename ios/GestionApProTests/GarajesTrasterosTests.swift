import Foundation
import Testing
@testable import GestionApPro

/// Garajes y trasteros (V12): tipos tolerantes al decodificar, textos según el tipo y alta por tipo.
@MainActor
struct GarajesTrasterosTests {

    @Test func sinTipo_esViviendaConHabitaciones_yUnTipoDesconocidoNoRompe() throws {
        let breve = try JSONCoding.decoder().decode(PisoBreve.self, from: Data(#"{"id":1,"direccion":"Calle A","ciudad":"Madrid"}"#.utf8))
        #expect(breve.tipoInmueble == .vivienda)
        let raro = try JSONCoding.decoder().decode(PisoBreve.self,
                                                   from: Data(#"{"id":1,"direccion":"Calle A","ciudad":"Madrid","tipo":"castillos"}"#.utf8))
        #expect(raro.tipoInmueble == .vivienda)
        let tipos = try JSONCoding.decoder().decode([TipoUnidad].self, from: Data(#"["plaza","trastero","otra"]"#.utf8))
        #expect(tipos == [.plaza, .trastero, .habitacion])
    }

    @Test func habitacionDeGaraje_conSusDatos() throws {
        let json = #"""
        {"id":7,"numero":3,"tipo":"plaza","metros":12.5,"planta":"-1","vehiculo":"moto","precio":110,"estado":"alquilada",
         "piso":{"id":2,"direccion":"Garaje Sol","ciudad":"Madrid","tipo":"garajes"},"idContratoActivo":4,"diasAlquilada":30}
        """#
        let h = try JSONCoding.decoder().decode(Habitacion.self, from: Data(json.utf8))
        #expect(h.unidad == .plaza)
        #expect(h.vehiculo == .moto)
        #expect(h.piso.tipoInmueble == .garajes)
        #expect(h.etiqueta == TipoUnidad.plaza.etiqueta(3))
        #expect(h.detalle?.contains("-1") == true)
        #expect(h.detalle?.contains("m²") == true)
    }

    @Test func pagoSinTipo_seEtiquetaComoHabitacion() throws {
        let json = #"""
        {"id":1,"fechaPago":"2026-11-02","cantidad":121,"metodoPago":"transferencia","idContrato":3,
         "inquilino":{"id":1,"nombre":"Ana"},"numeroHabitacion":2,"piso":{"id":1,"direccion":"A","ciudad":"M"}}
        """#
        let p = try JSONCoding.decoder().decode(Pago.self, from: Data(json.utf8))
        #expect(p.unidad == .habitacion)
        #expect(p.etiquetaUnidad == TipoUnidad.habitacion.etiqueta(2))
    }

    @Test func contratoConIva_seDecodifica() throws {
        let json = #"""
        {"id":5,"habitacion":{"id":7,"numero":1,"tipo":"plaza"},"piso":{"id":2,"direccion":"Garaje Sol","ciudad":"Madrid","tipo":"garajes"},
         "inquilino":{"id":1,"nombre":"Ana"},"fechaInicio":"2026-07-01","fechaFin":"2027-07-01","precioMensual":121,
         "aplicaIva":true,"ivaPct":21,"activo":true,"vencimiento":"NORMAL","diasRestantes":200}
        """#
        let c = try JSONCoding.decoder().decode(Contrato.self, from: Data(json.utf8))
        #expect(c.aplicaIva == true)
        #expect(c.ivaPct == 21)
        #expect(c.habitacion.unidad == .plaza)
    }

    @Test func textosConElGeneroDeCadaUnidad() {
        #expect(EstadoHabitacion.alquilada.nombre(para: .trastero) != EstadoHabitacion.alquilada.nombre(para: .plaza))
        #expect(TipoUnidad.trastero.alquiladas(1, de: 2) != TipoUnidad.plaza.alquiladas(1, de: 2))
        #expect(TipoUnidad.plaza.etiqueta(4) != TipoUnidad.trastero.etiqueta(4))
        #expect(TipoUnidad.habitacion.cantidad(1) != TipoUnidad.habitacion.cantidad(2))
        // Cada tipo propone su inventario y sus incidencias típicas.
        #expect(Set(TipoUnidad.plaza.elementosInventario) != Set(TipoUnidad.habitacion.elementosInventario))
        #expect(!TipoUnidad.trastero.incidenciasTipicas.isEmpty)
        #expect(Unidades.plural(conOtrosTipos: true) != Unidades.plural(conOtrosTipos: false))
    }

    @Test func reglasDeCadaTipo_comoEnLaAPI() {
        #expect(TipoInmueble.vivienda.unidadesAdmitidas == [.habitacion])
        #expect(TipoInmueble.garajes.unidadesAdmitidas == [.plaza, .trastero])
        #expect(TipoInmueble.trasteros.unidadesAdmitidas == [.trastero])
        #expect(TipoInmueble.vivienda.maximoUnidades == 50)
        #expect(TipoInmueble.garajes.maximoUnidades == 500)
    }

    @Test func altaDeGaraje_pidePlazasMetrosYPrecio() throws {
        let vm = NuevoPisoViewModel()
        vm.cambiarTipo(.garajes)
        #expect(vm.numeroHabitaciones == 10)
        vm.cambiarNumero(120)
        #expect(vm.numeroHabitaciones == 120)
        vm.metros = 12.5
        vm.planta = "-1"
        vm.vehiculo = .coche
        vm.aplicarATodas(95)
        let req = vm.peticion(idCiudad: 1)
        #expect(req.tipo == .garajes)
        #expect(req.habitaciones?.count == 120)
        let primera = try #require(req.habitaciones?.first)
        #expect(primera.tipo == .plaza && primera.metros == Decimal(string: "12.50") && primera.planta == "-1" && primera.vehiculo == .coche)
        // Volver a vivienda recorta al máximo de habitaciones y no manda datos de plaza.
        vm.cambiarTipo(.vivienda)
        #expect(vm.numeroHabitaciones == 50)
        let viv = vm.peticion(idCiudad: 1)
        #expect(viv.habitaciones?.first?.tipo == nil && viv.habitaciones?.first?.vehiculo == nil)
    }

    @Test func plantaConCaracteresRaros_noDejaAvanzar() {
        let vm = NuevoPisoViewModel()
        vm.direccion = "Calle de Alcalá 120"
        vm.idCiudad = 1
        vm.cambiarTipo(.trasteros)
        vm.elegirModo(.edificio)
        vm.planta = "<script>"
        #expect(vm.errorPlanta != nil)
        #expect(!vm.puedeAvanzar(desde: .basicos))
        vm.planta = "Sótano 2"
        #expect(vm.puedeAvanzar(desde: .basicos))
    }

    @Test func resumenDeCartera_diceUnidadesSiSeMezclanTipos() throws {
        func piso(_ tipo: String) throws -> Piso {
            try JSONCoding.decoder().decode(Piso.self, from: Data("""
            {"id":1,"direccion":"A","tipo":"\(tipo)","ciudad":{"id":1,"nombre":"Madrid"},"numeroHabitaciones":2,"idPropietario":1,
             "ocupacion":{"total":2,"alquiladas":1,"disponibles":1,"mantenimiento":0},"ingresosMensuales":100}
            """.utf8))
        }
        #expect(ResumenCartera([try piso("garajes")]).unidades == TipoUnidad.plaza.pluralMinusculas)
        #expect(ResumenCartera([try piso("vivienda"), try piso("trasteros")]).unidades == Unidades.plural(conOtrosTipos: true))
    }
}
