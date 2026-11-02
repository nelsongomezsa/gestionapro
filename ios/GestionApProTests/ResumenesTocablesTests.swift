import Foundation
import Testing
@testable import GestionApPro

/// Lógica de las tarjetas y alertas tocables de Inicio y de las hojas de rentabilidad del piso.
@MainActor
struct ResumenesTocablesTests {
    private func pisos() throws -> [Piso] { try Fixture.decodificar([Piso].self, de: "pisos") }
    private func habitaciones() throws -> [Habitacion] { try Fixture.decodificar([Habitacion].self, de: "habitaciones") }

    // MARK: Ocupación

    @Test func ocupacion_deMenorAMayor_yTotalSumado() throws {
        let lista = try pisos()
        let orden = ResumenesInicio.porOcupacion(lista)
        let pcts = orden.map { ResumenesInicio.porcentaje($0.ocupacion) }
        #expect(pcts == pcts.sorted())
        #expect(orden.first?.id == 8) // 1 de 3
        let total = ResumenesInicio.total(lista)
        #expect(total.total == 30)
        #expect(total.alquiladas == 20)
        #expect(total.mantenimiento == 4)
        #expect(ocupacionTexto(lista.first { $0.id == 8 }!.ocupacion) == "1 ocupada · 1 libre · 1 en mantenimiento")
    }

    // MARK: Habitaciones libres

    @Test func libres_filtraYOrdenaPorTiempoLibre() throws {
        let base = try habitaciones()
        let libre = base.first { $0.estado == .disponible }!
        #expect(libre.libreDesde != nil) // viene de la API (fixture)
        let otra = Habitacion(id: 90, numero: 7, precio: 400, estado: .disponible, piso: libre.piso,
                              inquilinoActual: nil, idContratoActivo: nil, diasAlquilada: nil, libreDesde: nil)
        let mant = Habitacion(id: 91, numero: 8, precio: 300, estado: .mantenimiento, piso: libre.piso,
                              inquilinoActual: nil, idContratoActivo: nil, diasAlquilada: nil,
                              libreDesde: libre.libreDesde!.addingTimeInterval(-86_400 * 30))
        let todas = base + [otra, mant]

        let soloLibres = ResumenesInicio.libres(todas, incluirMantenimiento: false)
        #expect(soloLibres.map(\.id) == [libre.id, 90]) // las que nunca tuvieron contrato, al final
        let conMant = ResumenesInicio.libres(todas, incluirMantenimiento: true)
        #expect(conMant.map(\.id) == [91, libre.id, 90]) // la que lleva más tiempo, primero
    }

    @Test func textoLibre_conDias() throws {
        let h = try habitaciones().first { $0.estado == .disponible }!
        let hoy = h.libreDesde!.addingTimeInterval(86_400 * 10 + 3600)
        #expect(ResumenesInicio.diasLibre(h, hoy: hoy) == 10)
        #expect(ResumenesInicio.textoLibre(h, hoy: hoy).hasSuffix("· 10 días"))
        #expect(ResumenesInicio.textoLibre(try habitaciones().first { $0.estado == .alquilada }!) == "Sin contratos anteriores")
    }

    // MARK: Alertas y filtros

    @Test func cadaAlertaAbreSuListaFiltrada() {
        let vencen = Alerta(tipo: "CONTRATOS_POR_VENCER", titulo: "5 contratos vencen", mensaje: "", tono: "aviso")
        let incid = Alerta(tipo: "INCIDENCIAS_PENDIENTES", titulo: "5 incidencias pendientes", mensaje: "", tono: "aviso")
        #expect(ResumenesInicio.destino(de: vencen) == .contratos(.porVencer))
        #expect(ResumenesInicio.destino(de: incid) == .incidencias(.pendientes))
        #expect(ResumenesInicio.destino(de: Alerta(tipo: "OTRA", titulo: "", mensaje: "", tono: "")) == nil)
    }

    @Test func filtroIncidencias_abiertasJuntaPendientesYEnCurso() {
        #expect(FiltroIncidencias.abiertas.incluye(.pendiente))
        #expect(FiltroIncidencias.abiertas.incluye(.enProceso))
        #expect(!FiltroIncidencias.abiertas.incluye(.resuelta))
        #expect(FiltroIncidencias.todas.incluye(.resuelta))
        #expect(!FiltroIncidencias.pendientes.incluye(.enProceso))
        #expect(ContratosViewModel(filtro: .porVencer).filtro == .porVencer)
    }

    // MARK: Rentabilidad

    @Test func ranking_porMetrica() throws {
        let lista = try pisos()
        // Bruta: el 3 (9,08 %) es el mejor; el 1 (5,85 %), el segundo.
        #expect(RankingRentabilidad.posicion(de: 3, entre: lista, por: .bruta) == .init(puesto: 1, de: 8))
        #expect(RankingRentabilidad.posicion(de: 1, entre: lista, por: .bruta) == .init(puesto: 2, de: 8))
        // PER: menos años es mejor y solo cuentan los pisos con PER (5).
        #expect(RankingRentabilidad.posicion(de: 3, entre: lista, por: .per) == .init(puesto: 1, de: 5))
        #expect(RankingRentabilidad.posicion(de: 6, entre: lista, por: .per) == nil)
        #expect(RankingRentabilidad.texto(.init(puesto: 2, de: 8)) == "2.º más rentable de 8")
        #expect(RankingRentabilidad.texto(.init(puesto: 1, de: 8)) == "El más rentable de 8")
    }

    @Test func pasos_usanLosNumerosDelPiso() throws {
        let p = try pisos().first { $0.id == 3 }!
        let m = try #require(p.metricas)
        let pasos = MetricaRentabilidad.bruta.pasos(p, m)
        #expect(pasos.first?.valor == Formato.euros(p.ingresosMensuales * 12))
        #expect(pasos.last?.esResultado == true)
        #expect(pasos.last?.valor == Formato.porcentaje(m.rentabilidadBrutaPct))
        #expect(MetricaRentabilidad.neta.pasos(p, m).count == 5)
    }

    @Test func cobrosYGastos_porMes() throws {
        let ingresos = [ImporteMes(mes: "2025-12", etiqueta: "dic", importe: 900),
                        ImporteMes(mes: "2026-01", etiqueta: "ene", importe: 950)]
        #expect(CobrosGastosMes.anios(de: ingresos) == [2025, 2026])
        let fecha = try Date("2026-01-15T12:00:00Z", strategy: .iso8601)
        let g = Gasto(id: 1, idPiso: 3, direccionPiso: "", idHabitacion: nil, numeroHabitacion: nil, idIncidencia: nil,
                      categoria: .ibi, concepto: "IBI", importe: 120, fecha: fecha, deducible: true, tieneFactura: false)
        let meses = CobrosGastosMes.combinar(ingresos: ingresos, gastos: [g, g])
        #expect(meses.map(\.gastos) == [0, 240])
        #expect(meses.map(\.cobros) == [900, 950])
    }

    @Test func calculadora_conLosDatosDelPiso() throws {
        let p = try pisos().first { $0.id == 3 }!
        let r = RentabilidadRequest.desde(p)
        #expect(r.alquilerMensual == p.ingresosMensuales.double)
        #expect(r.precioCompra == (p.datosFinancieros?.precioCompra?.double ?? 0))
        #expect(r.porcentajeFinanciado <= 100)
    }
}
