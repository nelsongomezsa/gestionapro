import Foundation

/// Cálculos de las pantallas que se abren desde las tarjetas de Inicio (sin vista, para probarlos).
enum ResumenesInicio {

    // MARK: Ocupación

    /// % de habitaciones alquiladas (0-100).
    static func porcentaje(_ o: Piso.Ocupacion) -> Double {
        o.total > 0 ? Double(o.alquiladas) * 100 / Double(o.total) : 0
    }

    /// Pisos de menor a mayor ocupación (primero los que necesitan atención); a igual %, por dirección.
    static func porOcupacion(_ pisos: [Piso]) -> [Piso] {
        pisos.sorted {
            let a = porcentaje($0.ocupacion), b = porcentaje($1.ocupacion)
            return a != b ? a < b : $0.direccion.localizedStandardCompare($1.direccion) == .orderedAscending
        }
    }

    /// Suma de la ocupación de todos los pisos.
    static func total(_ pisos: [Piso]) -> Piso.Ocupacion {
        var total = 0, alquiladas = 0, disponibles = 0, mantenimiento = 0
        for p in pisos {
            total += p.ocupacion.total
            alquiladas += p.ocupacion.alquiladas
            disponibles += p.ocupacion.disponibles
            mantenimiento += p.ocupacion.mantenimiento
        }
        return Piso.Ocupacion(total: total, alquiladas: alquiladas, disponibles: disponibles, mantenimiento: mantenimiento)
    }

    // MARK: Habitaciones libres

    /// Libres (y, si se pide, en mantenimiento): primero las que llevan más tiempo sin alquilar;
    /// las que nunca tuvieron contrato, al final. A igualdad, por piso y número.
    static func libres(_ habitaciones: [Habitacion], incluirMantenimiento: Bool) -> [Habitacion] {
        habitaciones
            .filter { $0.estado == .disponible || (incluirMantenimiento && $0.estado == .mantenimiento) }
            .sorted(by: antesLibre)
    }

    private static func antesLibre(_ a: Habitacion, _ b: Habitacion) -> Bool {
        if let x = a.libreDesde, let y = b.libreDesde, x != y { return x < y }
        if (a.libreDesde == nil) != (b.libreDesde == nil) { return a.libreDesde != nil }
        if a.piso.direccion != b.piso.direccion {
            return a.piso.direccion.localizedStandardCompare(b.piso.direccion) == .orderedAscending
        }
        return a.numero < b.numero
    }

    /// Días completos que lleva libre (0 si se liberó hoy); nil si no se sabe.
    static func diasLibre(_ h: Habitacion, hoy: Date = .now) -> Int? {
        guard let desde = h.libreDesde else { return nil }
        let cal = Calendar(identifier: .gregorian)
        return max(cal.dateComponents([.day], from: cal.startOfDay(for: desde), to: cal.startOfDay(for: hoy)).day ?? 0, 0)
    }

    /// "Libre desde el 1 sept. · 62 días" o "Sin contratos anteriores".
    static func textoLibre(_ h: Habitacion, hoy: Date = .now) -> String {
        guard let desde = h.libreDesde, let dias = diasLibre(h, hoy: hoy) else {
            return String(localized: "Sin contratos anteriores")
        }
        let fecha = desde.formatted(.dateTime.day().month(.abbreviated).locale(Formato.locale))
        if h.estado == .mantenimiento {
            return String(localized: "En mantenimiento desde el \(fecha)") + " · " + duracion(dias)
        }
        return String(localized: "Libre desde el \(fecha)") + " · " + duracion(dias)
    }

    /// "hoy", "1 día", "12 días".
    static func duracion(_ dias: Int) -> String {
        switch dias {
        case 0: String(localized: "hoy")
        case 1: String(localized: "1 día")
        default: String(localized: "\(dias) días")
        }
    }

    // MARK: Alertas

    /// Lista ya filtrada que abre cada alerta de Inicio.
    static func destino(de alerta: Alerta) -> DestinoInicio? {
        switch alerta.tipo {
        case "COBROS_ATRASADOS": .atrasados
        case "CONTRATOS_POR_VENCER": .contratos(.porVencer)
        case "INCIDENCIAS_PENDIENTES": .incidencias(.pendientes)
        case "OCUPACION": .ocupacion
        default: nil
        }
    }
}
