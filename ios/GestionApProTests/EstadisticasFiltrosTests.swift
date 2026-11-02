import Foundation
import Testing
@testable import GestionApPro

/// Fase 3: periodos, variaciones, análisis e informe en PDF.
@MainActor
struct EstadisticasFiltrosTests {
    private var madrid: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return c
    }
    private func fecha(_ a: Int, _ m: Int, _ d: Int) -> Date {
        madrid.date(from: DateComponents(year: a, month: m, day: d, hour: 12))!
    }
    private func ymd(_ f: Date) -> [Int] { [madrid.component(.year, from: f), madrid.component(.month, from: f), madrid.component(.day, from: f)] }

    @Test func periodos_mesTrimestreAnio_yDesplazar() {
        let ref = fecha(2026, 8, 17)
        let mes = PeriodoEstadisticas.de(.mes, en: ref)
        #expect(ymd(mes.desde) == [2026, 8, 1] && ymd(mes.hasta) == [2026, 8, 31])
        let t = PeriodoEstadisticas.de(.trimestre, en: ref)
        #expect(ymd(t.desde) == [2026, 7, 1] && ymd(t.hasta) == [2026, 9, 30])
        #expect(t.titulo == "T3 2026")
        let a = PeriodoEstadisticas.de(.anio, en: ref)
        #expect(ymd(a.desde) == [2026, 1, 1] && ymd(a.hasta) == [2026, 12, 31])
        #expect(ymd(mes.desplazado(-8).desde) == [2025, 12, 1])
        #expect(ymd(PeriodoEstadisticas.de(.mes, en: fecha(2026, 2, 3)).hasta) == [2026, 2, 28])
        #expect(ymd(t.desplazado(1).desde) == [2026, 10, 1])
        let libre = PeriodoEstadisticas(tipo: .personalizado, desde: fecha(2026, 1, 1), hasta: fecha(2026, 1, 10))
        #expect(ymd(libre.desplazado(-1).desde) == [2025, 12, 22] && ymd(libre.desplazado(-1).hasta) == [2025, 12, 31])
        #expect(!PeriodoEstadisticas.de(.anio).puedeAvanzar)
        #expect(PeriodoEstadisticas.de(.anio).desplazado(-1).puedeAvanzar)
    }

    @Test func variacion_frenteAlAnioAnterior() {
        #expect(variacionPct(120, 100) == 20)
        #expect(variacionPct(-50, -100) == 50)
        #expect(variacionPct(10, 0) == nil)
    }

    @Test func analisis_seDecodifica_yGeneraPDF() throws {
        let json = """
        {"desde":"2025-01-01","hasta":"2025-12-31","ambito":"CARTERA",
         "actual":{"ingresos":7900.00,"gastos":180.00,"neto":7720.00,"ocupacionPct":50.14,"diasMediosVacia":182.0,"habitaciones":3,
                   "contratosIniciados":2,"contratosFinalizados":2,"duracionMediaMeses":9.0,"rotacionPct":66.67,"impagado":500.00},
         "anterior":{"ingresos":0,"gastos":0,"neto":0,"ocupacionPct":0,"diasMediosVacia":365,"habitaciones":3,
                   "contratosIniciados":0,"contratosFinalizados":0,"duracionMediaMeses":null,"rotacionPct":0,"impagado":0},
         "pisos":[{"piso":{"id":1,"direccion":"Calle A 1","ciudad":"Madrid"},"ingresos":7900,"gastos":130,"neto":7770,"ocupacionPct":75.2,"diasMediosVacia":90.5,"habitaciones":2},
                  {"piso":{"id":2,"direccion":"Calle B 2","ciudad":"Madrid"},"ingresos":0,"gastos":50,"neto":-50,"ocupacionPct":0,"diasMediosVacia":365,"habitaciones":1}],
         "meses":[{"mes":"2025-01","etiqueta":"ene","ingresos":500,"gastos":0,"ocupacionPct":33.33}],
         "morosidad":[{"idInquilino":4,"nombre":"Lucía Pérez","mesesDebidos":12,"mesesImpagados":1,"pagosFueraDePlazo":1,"importeImpagado":500.00,"puntualidadPct":83.33}]}
        """
        let a = try JSONCoding.decoder().decode(Analisis.self, from: Data(json.utf8))
        #expect(a.pisos.first?.neto == 7770)
        #expect(a.anterior.duracionMediaMeses == nil)
        #expect(a.morosidad.first?.mesesImpagados == 1)
        let pdf = EstadisticasViewModel().pdf(a)
        #expect(pdf.datos.starts(with: Data("%PDF".utf8)))
        #expect(AmbitoEstadisticas.cartera.titulo == "Toda la cartera")
    }
}
