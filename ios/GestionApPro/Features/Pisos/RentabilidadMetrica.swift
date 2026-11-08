import Foundation

/// Las cuatro métricas de rentabilidad del detalle del piso; cada tarjeta abre su hoja explicativa.
enum MetricaRentabilidad: String, CaseIterable, Identifiable, Hashable, Sendable {
    case bruta, neta, cashOnCash, per

    var id: Self { self }

    var titulo: String {
        switch self {
        case .bruta: String(localized: "Rentabilidad bruta")
        case .neta: String(localized: "Rentabilidad neta")
        case .cashOnCash: String(localized: "Cash-on-cash")
        case .per: String(localized: "PER inmobiliario")
        }
    }

    /// La fórmula en palabras.
    var formula: String {
        switch self {
        case .bruta: String(localized: "Alquiler anual ÷ inversión total")
        case .neta: String(localized: "(Alquiler anual − gastos anuales) ÷ inversión total")
        case .cashOnCash: String(localized: "Cash flow anual ÷ capital propio")
        case .per: String(localized: "Inversión total ÷ alquiler anual")
        }
    }

    var explicacion: String {
        switch self {
        case .bruta: String(localized: "Lo que rinde el piso sin descontar gastos ni la hipoteca.")
        case .neta: String(localized: "Lo que rinde tras los gastos del inmueble, antes de la financiación.")
        case .cashOnCash: String(localized: "Lo que te devuelve al año el dinero que pusiste de tu bolsillo, ya pagada la hipoteca.")
        case .per: String(localized: "Los años de alquiler que hacen falta para recuperar lo invertido.")
        }
    }

    /// En el PER, cuanto menos, mejor.
    var mayorEsMejor: Bool { self != .per }

    func valor(_ m: Piso.Metricas) -> Double? {
        switch self {
        case .bruta: m.rentabilidadBrutaPct
        case .neta: m.rentabilidadNetaPct
        case .cashOnCash: m.cashOnCashPct
        case .per: m.perAnios
        }
    }

    func texto(_ m: Piso.Metricas) -> String {
        self == .per ? Formato.anios(m.perAnios) : Formato.porcentaje(valor(m))
    }

    /// Paso a paso con los números reales del piso.
    func pasos(_ piso: Piso, _ m: Piso.Metricas) -> [PasoCalculo] {
        let mensual = piso.ingresosMensuales
        let anual = mensual * 12
        let alquiler = PasoCalculo(titulo: String(localized: "Alquiler anual"), valor: Formato.euros(anual),
                                   nota: String(localized: "\(Formato.euros(mensual)) al mes × 12"))
        let inversion = PasoCalculo(titulo: String(localized: "Inversión total"), valor: Formato.euros(m.inversionTotal),
                                    nota: String(localized: "Compra, impuestos, reforma y mobiliario"))
        switch self {
        case .bruta:
            return [alquiler, inversion.operando("÷"), resultado(m)]
        case .neta:
            let gastos = PasoCalculo(titulo: String(localized: "Gastos anuales"), valor: "− " + Formato.euros(m.gastosAnuales),
                                     nota: m.gastosReales == true ? String(localized: "Gastos reales de los últimos 12 meses")
                                                                   : String(localized: "Estimados con los datos del inmueble"))
            let neto = PasoCalculo(titulo: String(localized: "Alquiler neto"), valor: Formato.euros(anual - m.gastosAnuales))
            return [alquiler, gastos, neto, inversion.operando("÷"), resultado(m)]
        case .cashOnCash:
            let cf = PasoCalculo(titulo: String(localized: "Cash flow anual"), valor: Formato.euros(m.cashFlowMensual * 12),
                                 nota: String(localized: "\(Formato.euros(m.cashFlowMensual)) al mes × 12 (alquiler − hipoteca − gastos)"))
            let capital = PasoCalculo(titulo: String(localized: "Capital propio"), valor: Formato.euros(m.capitalPropio),
                                      nota: String(localized: "Inversión total menos la hipoteca"))
            return [cf, capital.operando("÷"), resultado(m)]
        case .per:
            return [inversion, alquiler.operando("÷"), resultado(m)]
        }
    }

    private func resultado(_ m: Piso.Metricas) -> PasoCalculo {
        PasoCalculo(titulo: titulo, valor: texto(m), operador: "=", esResultado: true)
    }
}

struct PasoCalculo: Hashable {
    let titulo: String
    let valor: String
    var nota: String? = nil
    /// "÷", "=" o nil: se pinta delante del valor.
    var operador: String? = nil
    var esResultado = false

    func operando(_ op: String) -> PasoCalculo {
        PasoCalculo(titulo: titulo, valor: valor, nota: nota, operador: op, esResultado: esResultado)
    }
}

/// Posición del piso entre los del usuario para una métrica ("2.º más rentable de 8").
enum RankingRentabilidad {
    struct Posicion: Equatable {
        let puesto: Int
        let de: Int
    }

    /// Solo cuentan los pisos con la métrica calculable. Los empates comparten puesto.
    static func posicion(de idPiso: Int, entre pisos: [Piso], por metrica: MetricaRentabilidad) -> Posicion? {
        let valores = pisos.compactMap { p in p.metricas.flatMap(metrica.valor).map { (p.id, $0) } }
        guard let propio = valores.first(where: { $0.0 == idPiso })?.1 else { return nil }
        let mejores = valores.filter { metrica.mayorEsMejor ? $0.1 > propio : $0.1 < propio }.count
        return Posicion(puesto: mejores + 1, de: valores.count)
    }

    static func texto(_ p: Posicion) -> String {
        if p.de == 1 { return String(localized: "Es el único inmueble con este dato") }
        return p.puesto == 1 ? String(localized: "El más rentable de \(p.de)")
                             : String(localized: "\(p.puesto).º más rentable de \(p.de)")
    }
}

/// Cobros y gastos reales de un mes, para el gráfico de la hoja.
struct CobrosGastosMes: Identifiable, Hashable {
    let mes: String
    let etiqueta: String
    let cobros: Decimal
    let gastos: Decimal
    var id: String { mes }

    /// Une los cobros de 12 meses (de la API) con los gastos reales de esos mismos meses.
    static func combinar(ingresos: [ImporteMes], gastos: [Gasto]) -> [CobrosGastosMes] {
        var madrid = Calendar(identifier: .gregorian)
        madrid.timeZone = TimeZone(identifier: "Europe/Madrid")!
        var porMes: [String: Decimal] = [:]
        for g in gastos {
            let c = madrid.dateComponents([.year, .month], from: g.fecha)
            guard let a = c.year, let m = c.month else { continue }
            porMes[String(format: "%04d-%02d", a, m), default: 0] += g.importe
        }
        return ingresos.map { CobrosGastosMes(mes: $0.mes, etiqueta: $0.etiqueta, cobros: $0.importe, gastos: porMes[$0.mes] ?? 0) }
    }

    /// Años que cubren esos meses ("2025-11" … "2026-10" → 2025 y 2026), para pedir sus gastos.
    static func anios(de ingresos: [ImporteMes]) -> [Int] {
        Array(Set(ingresos.compactMap { Int($0.mes.prefix(4)) })).sorted()
    }
}

extension RentabilidadRequest {
    /// Los datos del piso en la calculadora, para simular cambios (precio, alquiler, hipoteca...).
    /// La comunidad autónoma no se sabe por la ciudad: se deja la de por defecto y se puede cambiar.
    @MainActor static func desde(_ piso: Piso) -> RentabilidadRequest {
        var r = CalculadoraViewModel.vacio
        let d = piso.datosFinancieros
        func n(_ v: Decimal?) -> Double { v?.double ?? 0 }
        r.precioCompra = n(d?.precioCompra)
        r.gastosNotariaRegistro = n(d?.gastosNotaria) + n(d?.gastosRegistro)
        r.reforma = n(d?.costeReforma)
        r.mobiliario = n(d?.costeMobiliario)
        r.comisionCompra = n(d?.otrosGastosCompra)
        r.ibiMensual = n(d?.gastoIbiAnual) / 12
        r.segurosMensual = n(d?.gastoSeguroAnual) / 12
        r.comunidadMensual = n(d?.gastoComunidadMensual)
        r.mantenimientoMensual = n(d?.gastoMantenimientoAnual) / 12
        r.alquilerMensual = piso.ingresosMensuales.double
        if let d, d.tieneHipoteca, let compra = d.precioCompra, compra > 0 {
            r.porcentajeFinanciado = min(n(d.importeHipoteca) / compra.double * 100, 100)
            r.plazoAnos = d.plazoAnos ?? 0
            r.tipoInteresPct = n(d.tipoInteres)
        }
        r.comunidad = CalculadoraViewModel.ejemplo.comunidad
        return r
    }
}
