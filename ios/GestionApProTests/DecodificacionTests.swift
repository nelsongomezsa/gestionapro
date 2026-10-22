import Foundation
import Testing
@testable import GestionApPro

/// Decodificación de respuestas REALES de la API (Fixtures/*.json).
@Suite("Decodificación de modelos")
struct DecodificacionTests {

    @Test func login() throws {
        let r = try Fixture.decodificar(TokenResponse.self, de: "login")
        #expect(r.tipo == "Bearer")
        #expect(r.usuario == Usuario(id: 1, nombre: "Administrador", email: "admin@gestionap.com", rol: .admin, idInquilino: nil))
        // "2026-10-22T17:09:19.399579Z": Instant con microsegundos, que .iso8601 no admite.
        let c = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: r.expira)
        #expect((c.year, c.month, c.day, c.hour, c.minute, c.second) == (2026, 10, 22, 17, 9, 19))
    }

    @Test func me() throws {
        let u = try Fixture.decodificar(Usuario.self, de: "me")
        #expect(u.rol == .admin)
        #expect(u.rol.gestionaPisos)
        #expect(u.idInquilino == nil)
    }

    @Test func pisos_losOchoDeLaBD() throws {
        let pisos = try Fixture.decodificar([Piso].self, de: "pisos")
        #expect(pisos.count == 8)
        #expect(Set(pisos.map(\.id)) == Set(1...8))
        #expect(pisos.allSatisfy { $0.metricas != nil && $0.datosFinancieros != nil })
    }

    @Test func piso_metricasConDecimalesExactos_yCamposAusentes() throws {
        let pisos = try Fixture.decodificar([Piso].self, de: "pisos")
        let puerto = try #require(pisos.first { $0.id == 6 })
        let m = try #require(puerto.metricas)

        #expect(puerto.ciudad.nombre == "Valencia")
        #expect(puerto.ocupacion == .init(total: 4, alquiladas: 2, disponibles: 1, mantenimiento: 1))
        #expect(puerto.ingresosMensuales == 0)
        #expect(m.calificacion == .aRevisar)
        #expect(m.cashFlowMensual == Decimal(string: "-436.22"))
        #expect(m.inversionTotal == Decimal(string: "105400.00"))
        #expect(m.cashOnCashPct == -10.3862)
        #expect(m.rentabilidadBrutaPct == 0.0)
        #expect(m.perAnios == nil, "La API omite perAnios cuando no hay ingresos")

        let df = try #require(puerto.datosFinancieros)
        #expect(df.tieneHipoteca)
        #expect(df.cuotaMensualHipoteca == Decimal(string: "299.55"))
        let compra = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "Europe/Madrid")!, from: try #require(df.fechaCompra))
        #expect((compra.year, compra.month, compra.day) == (2020, 11, 8))
    }

    @Test func piso_excelenteConPer() throws {
        let pisos = try Fixture.decodificar([Piso].self, de: "pisos")
        let m = try #require(pisos.first { $0.id == 3 }?.metricas)
        #expect(m.calificacion == .excelente)
        #expect(m.perAnios == 11.02)
    }

    @Test func piso_sinDatosFinancieros_noTieneMetricas() throws {
        let json = """
        {"id":9,"direccion":"Calle Nueva 1","ciudad":{"id":1,"nombre":"Madrid"},"numeroHabitaciones":2,
         "idPropietario":1,"ocupacion":{"total":0,"alquiladas":0,"disponibles":0,"mantenimiento":0},
         "ingresosMensuales":0}
        """
        let piso = try JSONCoding.decoder().decode(Piso.self, from: Data(json.utf8))
        #expect(piso.metricas == nil)
        #expect(piso.datosFinancieros == nil)
        #expect((piso.metricas?.calificacion).texto == "Sin datos")
    }

    @Test func valoresDesconocidosDeEnum_noRompenLaDecodificacion() throws {
        let u = try JSONCoding.decoder().decode(Usuario.self, from: Data(#"{"id":1,"nombre":"X","email":"x@x","rol":"SUPERVISOR"}"#.utf8))
        #expect(u.rol == .desconocido)
        #expect(!u.rol.gestionaPisos)
        let c = try JSONCoding.decoder().decode([Calificacion].self, from: Data(#"["EXCELENTE","NUEVA"]"#.utf8))
        #expect(c == [.excelente, .desconocida])
    }

    @Test func itp_19Comunidades() throws {
        let itp = try Fixture.decodificar(ItpResponse.self, de: "itp")
        #expect(itp.comunidades.count == 19)
        #expect(itp.comunidades.first { $0.nombre == "Canarias" }?.tipoPct == 6.5)
        #expect(itp.anioReferencia != nil)
    }

    @Test func rentabilidad_casoMadrid() throws {
        let r = try Fixture.decodificar(RentabilidadResponse.self, de: "rentabilidad")
        #expect(r.itpImporte == 12000)
        #expect(r.cuotaMensual == Decimal(string: "775.49"))
        #expect(r.rentabilidadBrutaPct == Decimal(string: "7.21"))
        #expect(r.cashFlowMensual == Decimal(string: "364.51"))
        #expect(r.aniosRecuperacion == Decimal(string: "16.69"))
        #expect(r.plusvalia10Anios == Decimal(string: "68783.28"))
    }

    @Test func errorDeValidacion_conErroresPorCampo() throws {
        let e = try Fixture.decodificar(ErrorAPI.self, de: "error400")
        #expect(e.status == 400)
        #expect(e.codigo == "VALIDACION")
        #expect(Set(e.errores?.map(\.campo) ?? []) == ["idCiudad", "numeroHabitaciones", "direccion"])
    }

    @Test func errorSinCampos() throws {
        let e = try Fixture.decodificar(ErrorAPI.self, de: "error401")
        #expect(e.codigo == "CREDENCIALES_INCORRECTAS")
        #expect(e.errores == nil)
    }

    @Test func fechaLocalSinZona_seInterpretaEnHoraDeMadrid() throws {
        // Así llega "expira" en las invitaciones (LocalDateTime de Java).
        let fecha = try #require(JSONCoding.fecha("2026-10-29T18:52:36.478728"))
        let c = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "Europe/Madrid")!, from: fecha)
        #expect((c.day, c.hour, c.minute) == (29, 18, 52))
        #expect(JSONCoding.fecha("no es una fecha") == nil)
    }
}

@Suite("Formatos es_ES")
struct FormatoTests {
    @Test func euros() {
        #expect(sinEspaciosDuros(Formato.euros(Decimal(string: "85000.00")!)) == "85.000,00 €")
        #expect(sinEspaciosDuros(Formato.euros(Decimal(string: "-436.22")!)) == "-436,22 €")
        #expect(Formato.euros(nil as Decimal?) == "—")
    }

    @Test func porcentajes_laAPIMandaPuntosPorcentuales() {
        #expect(sinEspaciosDuros(Formato.porcentaje(7.6712)) == "7,67 %")
        #expect(sinEspaciosDuros(Formato.porcentaje(-10.3862)) == "-10,39 %")
        #expect(Formato.porcentaje(nil as Double?) == "—")
    }
}
