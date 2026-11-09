import Foundation

/// Unidad suelta: un inmueble con una sola plaza o un solo trastero, comprado por separado.
extension Piso {
    var esUnidadSuelta: Bool {
        tipoInmueble != .vivienda && numeroHabitaciones == 1 && ocupacion.total <= 1
    }

    /// El grupo de la lista de Inmuebles al que pertenece; nil si no es una unidad suelta.
    var grupoSueltas: GrupoSueltas? {
        guard esUnidadSuelta else { return nil }
        return tipoInmueble == .trasteros ? .trasteros : .plazas
    }

    /// Texto de la tarjeta mientras no se conoce el detalle de la unidad (o en el mapa).
    var situacionSueltaBreve: String {
        let unidad = tipoInmueble.unidad
        if ocupacion.alquiladas > 0 { return unidad == .trastero ? String(localized: "Alquilado") : String(localized: "Alquilada") }
        return ocupacion.mantenimiento > 0 ? String(localized: "En mantenimiento") : String(localized: "Libre")
    }
}

extension Habitacion {
    /// "Alquilada a Ana Ruiz", "Alquilado a Ana Ruiz", "Libre desde 1 oct 2026", "En mantenimiento" o "Libre".
    var situacionSuelta: String {
        if estado == .alquilada, let nombre = inquilinoActual?.nombre {
            return unidad == .trastero ? String(localized: "Alquilado a \(nombre)") : String(localized: "Alquilada a \(nombre)")
        }
        if estado == .mantenimiento { return String(localized: "En mantenimiento") }
        if let libreDesde {
            let fecha = libreDesde.formatted(.dateTime.day().month(.abbreviated).year().locale(Formato.localeFechas))
            return String(localized: "Libre desde \(fecha)")
        }
        return String(localized: "Libre")
    }
}

/// Agrupación de la lista de Inmuebles: todas las unidades sueltas del mismo tipo.
enum GrupoSueltas: String, CaseIterable, Identifiable, Sendable {
    case plazas, trasteros

    var id: Self { self }

    var nombre: String {
        switch self {
        case .plazas: String(localized: "Plazas sueltas")
        case .trasteros: String(localized: "Trasteros sueltos")
        }
    }

    var icono: String { self == .plazas ? TipoUnidad.plaza.icono : TipoUnidad.trastero.icono }
}

/// Cash flow y rentabilidad del conjunto. La rentabilidad total no es la media de porcentajes: pondera
/// por lo invertido en cada unidad (alquiler anual de todas / inversión de todas), igual que la de un inmueble.
struct TotalesSueltas: Equatable {
    let cashFlowMensual: Decimal
    let rentabilidadBrutaPct: Double?

    init(_ pisos: [Piso]) {
        let conDatos = pisos.filter { $0.metricas != nil }
        cashFlowMensual = conDatos.reduce(0) { $0 + ($1.metricas?.cashFlowMensual ?? 0) }
        let inversion = conDatos.reduce(Decimal(0)) { $0 + ($1.metricas?.inversionTotal ?? 0) }
        let ingresos = conDatos.reduce(Decimal(0)) { $0 + $1.ingresosMensuales }
        rentabilidadBrutaPct = inversion > 0
            ? NSDecimalNumber(decimal: ingresos * 12 / inversion * 100).doubleValue
            : nil
    }
}

/// Ranking de unidades sueltas en Estadísticas: de mejor a peor; las que no tienen datos, al final.
enum RankingSueltas {
    enum Criterio: String, CaseIterable, Identifiable, Sendable {
        case rentabilidad, cashFlow

        var id: Self { self }

        var nombre: String {
            switch self {
            case .rentabilidad: String(localized: "Rentabilidad")
            case .cashFlow: String(localized: "Cash flow")
            }
        }
    }

    static func ordenar(_ pisos: [Piso], por criterio: Criterio) -> [Piso] {
        pisos.sorted { a, b in
            switch criterio {
            case .rentabilidad:
                (a.metricas?.rentabilidadBrutaPct ?? -.infinity) > (b.metricas?.rentabilidadBrutaPct ?? -.infinity)
            case .cashFlow:
                (a.metricas?.cashFlowMensual ?? -.greatestFiniteMagnitude) > (b.metricas?.cashFlowMensual ?? -.greatestFiniteMagnitude)
            }
        }
    }
}
