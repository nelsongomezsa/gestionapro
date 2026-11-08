import Foundation
import Observation

/// Periodo de las estadísticas: mes, trimestre o año que contiene una fecha, o un rango libre.
struct PeriodoEstadisticas: Equatable, Sendable {
    enum Tipo: String, CaseIterable, Identifiable, Sendable {
        case mes, trimestre, anio, personalizado
        var id: Self { self }
        var nombre: String {
            switch self {
            case .mes: String(localized: "Mes")
            case .trimestre: String(localized: "Trimestre")
            case .anio: String(localized: "Año")
            case .personalizado: String(localized: "Personalizado")
            }
        }
    }

    var tipo: Tipo
    var desde: Date
    var hasta: Date

    private static var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        c.locale = Formato.localeFechas
        return c
    }

    /// El mes, trimestre o año que contiene `fecha` (con `personalizado`, los últimos 30 días hasta ella).
    static func de(_ tipo: Tipo, en fecha: Date = .now) -> PeriodoEstadisticas {
        let c = calendario
        let anio = c.component(.year, from: fecha), mes = c.component(.month, from: fecha)
        func dia(_ a: Int, _ m: Int, _ d: Int) -> Date { c.date(from: DateComponents(year: a, month: m, day: d, hour: 12))! }
        func finDeMes(_ a: Int, _ m: Int) -> Date { c.date(byAdding: DateComponents(month: 1, day: -1), to: dia(a, m, 1))! }
        switch tipo {
        case .mes: return .init(tipo: tipo, desde: dia(anio, mes, 1), hasta: finDeMes(anio, mes))
        case .trimestre:
            let primero = (mes - 1) / 3 * 3 + 1
            return .init(tipo: tipo, desde: dia(anio, primero, 1), hasta: finDeMes(anio, primero + 2))
        case .anio: return .init(tipo: tipo, desde: dia(anio, 1, 1), hasta: dia(anio, 12, 31))
        case .personalizado: return .init(tipo: tipo, desde: c.date(byAdding: .day, value: -29, to: fecha)!, hasta: fecha)
        }
    }

    /// El periodo anterior o siguiente del mismo tipo (un rango libre se desplaza su propia duración).
    func desplazado(_ pasos: Int) -> PeriodoEstadisticas {
        let c = Self.calendario
        switch tipo {
        case .mes: return .de(.mes, en: c.date(byAdding: .month, value: pasos, to: desde)!)
        case .trimestre: return .de(.trimestre, en: c.date(byAdding: .month, value: 3 * pasos, to: desde)!)
        case .anio: return .de(.anio, en: c.date(byAdding: .year, value: pasos, to: desde)!)
        case .personalizado:
            let dias = (c.dateComponents([.day], from: desde, to: hasta).day ?? 0) + 1
            return .init(tipo: tipo, desde: c.date(byAdding: .day, value: dias * pasos, to: desde)!,
                         hasta: c.date(byAdding: .day, value: dias * pasos, to: hasta)!)
        }
    }

    /// "Octubre 2026", "3.er trimestre 2026", "2026" o "1 oct. – 30 oct. 2026".
    var titulo: String {
        let c = Self.calendario
        let anio = c.component(.year, from: desde)
        switch tipo {
        case .mes:
            let m = c.standaloneMonthSymbols[c.component(.month, from: desde) - 1]
            return m.prefix(1).uppercased() + m.dropFirst() + " \(anio)"
        case .trimestre: return String(localized: "T\((c.component(.month, from: desde) - 1) / 3 + 1) \(String(anio))")
        case .anio: return String(anio)
        case .personalizado:
            let f = Date.FormatStyle.dateTime.day().month(.abbreviated).year().locale(Formato.localeFechas)
            return "\(desde.formatted(f)) – \(hasta.formatted(f))"
        }
    }

    /// No se avanza a periodos que empiezan después de hoy.
    var puedeAvanzar: Bool { desplazado(1).desde <= .now }
}

/// Qué se analiza: toda la cartera, solo un tipo de inmueble, un piso o una unidad.
enum AmbitoEstadisticas: Hashable, Sendable {
    case cartera
    case tipo(TipoInmueble)
    case piso(PisoBreve)
    case habitacion(Habitacion)

    var titulo: String {
        switch self {
        case .cartera: String(localized: "Toda la cartera")
        case let .tipo(t): String(localized: "Cartera · \(t.nombre)")
        case let .piso(p): p.direccion
        case let .habitacion(h): String(localized: "\(h.etiqueta) · \(h.piso.direccion)")
        }
    }
}

@MainActor
@Observable
final class EstadisticasViewModel {
    var periodo = PeriodoEstadisticas.de(.anio)
    var ambito: AmbitoEstadisticas = .cartera
    private(set) var analisis: EstadoCarga<Analisis> = .cargando
    /// Recargando con un análisis ya en pantalla (se atenúa en vez de vaciarse).
    private(set) var cargando = false
    /// Situación de hoy (habitaciones por estado e incidencias): no depende del filtro.
    private(set) var situacion: Estadisticas?
    private(set) var pisos: [Piso] = []
    private(set) var habitaciones: [Habitacion] = []
    var error: String?

    /// Tipos presentes: el filtro por tipo solo se ofrece si hay más de uno.
    var tiposPresentes: [TipoInmueble] {
        let presentes = Set(pisos.map(\.tipoInmueble))
        return TipoInmueble.allCases.filter(presentes.contains)
    }

    /// "habitaciones", "plazas", "trasteros" o "unidades", según lo que se analiza.
    var unidades: String {
        switch ambito {
        case .cartera: Unidades.plural(conOtrosTipos: pisos.contains { $0.tipoInmueble != .vivienda })
        case let .tipo(t): t.unidad.pluralMinusculas
        case let .piso(p): p.tipoInmueble.unidad.pluralMinusculas
        case let .habitacion(h): h.unidad.pluralMinusculas
        }
    }

    /// Solo habitaciones (para los textos que dicen "por habitación").
    var soloHabitaciones: Bool { unidades == TipoUnidad.habitacion.pluralMinusculas }

    func cargarListas(con api: APIClient) async {
        async let p = try? api.enviar(.pisos)
        async let h = try? api.enviar(.habitaciones())
        async let s = try? api.enviar(.estadisticas)
        pisos = ((await p) ?? []).sorted { $0.direccion.localizedStandardCompare($1.direccion) == .orderedAscending }
        habitaciones = (await h) ?? []
        situacion = await s
    }

    func cargar(con api: APIClient) async {
        let (piso, habitacion): (Int?, Int?) = switch ambito {
        case .cartera, .tipo: (nil, nil)
        case let .piso(p): (p.id, nil)
        case let .habitacion(h): (nil, h.id)
        }
        let tipo: TipoInmueble? = if case let .tipo(t) = ambito { t } else { nil }
        if analisis.valor == nil { analisis = .cargando }
        cargando = true
        defer { cargando = false }
        do {
            let a = try await api.enviar(.analisis(desde: periodo.desde, hasta: periodo.hasta, piso: piso, habitacion: habitacion, tipo: tipo))
            guard !Task.isCancelled else { return }
            analisis = .cargado(a)
        } catch .noAutorizado {
        } catch {
            if analisis.valor == nil { analisis = .error(error.localizedDescription) } else { self.error = error.localizedDescription }
        }
    }

    func cambiarTipo(_ tipo: PeriodoEstadisticas.Tipo) {
        guard tipo != periodo.tipo else { return }
        // Un rango libre no puede acabar después de hoy.
        let hasta = min(periodo.hasta, .now)
        periodo = tipo == .personalizado ? PeriodoEstadisticas(tipo: .personalizado, desde: min(periodo.desde, hasta), hasta: hasta)
                                         : .de(tipo, en: hasta)
    }

    /// Informe del periodo en PDF: resumen, comparación, ranking, meses y morosidad.
    func pdf(_ a: Analisis) -> DocumentoPDF {
        let t = a.actual, ant = a.anterior
        func comp(_ x: Decimal, _ y: Decimal) -> String {
            let v = variacionPct(x, y).map { " (\($0 >= 0 ? "+" : "")\(Formato.porcentaje($0)))" } ?? ""
            return "\(Formato.euros(x)) · \(String(localized: "año anterior")) \(Formato.euros(y))\(v)"
        }
        var secciones: [(String, [(String, String)])] = [
            (String(localized: "Resumen"), [
                (String(localized: "Ingresos"), comp(t.ingresos, ant.ingresos)),
                (String(localized: "Gastos"), comp(t.gastos, ant.gastos)),
                (String(localized: "Resultado neto"), comp(t.neto, ant.neto)),
                (String(localized: "Ocupación"), "\(Formato.porcentaje(t.ocupacionPct)) · \(String(localized: "año anterior")) \(Formato.porcentaje(ant.ocupacionPct))"),
                (String(localized: "Días medios vacía"), Formato.numero(t.diasMediosVacia)),
                (String(localized: "Rotación"), "\(Formato.porcentaje(t.rotacionPct)) · "
                    + String(localized: "\(t.contratosIniciados) altas · \(t.contratosFinalizados) bajas")),
                (String(localized: "Impagado"), Formato.euros(t.impagado)),
            ]),
        ]
        if a.pisos.count > 1 {
            secciones.append((String(localized: "Ranking de pisos"), a.pisos.enumerated().map { i, p in
                ("\(i + 1). \(p.piso.direccion)",
                 "\(Formato.euros(p.neto)) · \(Formato.porcentaje(p.ocupacionPct))")
            }))
        }
        secciones.append((String(localized: "Por mes"), a.meses.map { m in
            (m.etiqueta.capitalized(with: Formato.localeFechas),
             "\(Formato.euros(m.ingresos)) − \(Formato.euros(m.gastos))"
                + (m.ocupacionPct.map { " · \(Formato.porcentaje($0))" } ?? ""))
        }))
        if !a.morosidad.isEmpty {
            secciones.append((String(localized: "Morosidad"), a.morosidad.map { m in
                (m.nombre, "\(Formato.euros(m.importeImpagado)) · \(String(localized: "puntualidad")) \(Formato.porcentaje(m.puntualidadPct))")
            }))
        }
        let titulo = String(localized: "Estadísticas")
        return DocumentoPDF(titulo: "\(titulo) \(periodo.titulo)",
                            datos: GeneradorPDF.secciones(titulo: titulo, subtitulo: "\(ambito.titulo) · \(periodo.titulo)", secciones))
    }
}
