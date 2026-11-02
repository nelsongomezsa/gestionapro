import Foundation

/// Resumen de la cabecera de cada piso cuando una lista se agrupa "Por piso".
enum ResumenPorPiso {
    static func contratos(_ lista: [Contrato]) -> String {
        let renta = lista.reduce(Decimal(0)) { $0 + $1.precioMensual }
        return lista.count == 1 ? String(localized: "1 contrato · \(Formato.euros(renta)) al mes")
                                : String(localized: "\(lista.count) contratos · \(Formato.euros(renta)) al mes")
    }

    static func incidencias(_ lista: [Incidencia]) -> String {
        let pendientes = lista.filter { $0.estado == .pendiente }.count
        let total = lista.count == 1 ? String(localized: "1 incidencia") : String(localized: "\(lista.count) incidencias")
        guard pendientes > 0 else { return total }
        return total + " · " + (pendientes == 1 ? String(localized: "1 pendiente") : String(localized: "\(pendientes) pendientes"))
    }

    static func inquilinos(_ lista: [Inquilino]) -> String {
        let conApp = lista.filter(\.tieneCuentaApp).count
        let total = lista.count == 1 ? String(localized: "1 inquilino") : String(localized: "\(lista.count) inquilinos")
        return conApp == 0 ? total : total + " · " + String(localized: "\(conApp) con la app")
    }

    static func cobros(_ lista: [ElementoCobro]) -> String {
        var cobrado = Decimal(0), pendiente = Decimal(0)
        for e in lista {
            switch e {
            case let .pago(p): cobrado += p.cantidad
            case let .pendiente(p): pendiente += p.importe
            }
        }
        return pendiente > 0 ? String(localized: "Cobrado \(Formato.euros(cobrado)) · pendiente \(Formato.euros(pendiente))")
                             : String(localized: "Cobrado \(Formato.euros(cobrado))")
    }
}

/// Fila de Cobros agrupada por piso: un pendiente del mes o un pago registrado.
enum ElementoCobro: Identifiable {
    case pendiente(ResumenPagos.Pendiente)
    case pago(Pago)

    var id: String {
        switch self {
        case let .pendiente(p): "pendiente-\(p.id)"
        case let .pago(p): "pago-\(p.id)"
        }
    }

    var piso: PisoBreve {
        switch self {
        case let .pendiente(p): p.piso
        case let .pago(p): p.piso
        }
    }
}
