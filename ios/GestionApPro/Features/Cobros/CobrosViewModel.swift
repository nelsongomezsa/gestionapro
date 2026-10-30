import Foundation
import Observation

@MainActor
@Observable
final class CobrosViewModel {
    var mes: Mes = .actual
    private(set) var resumen: EstadoCarga<ResumenPagos> = .cargando
    private(set) var pagos: [Pago] = []
    var filtroInquilino: Int?
    var busqueda = ""
    var error: String?

    /// Filtro por inquilino y búsqueda por nombre, dirección o número de habitación (como el escritorio).
    var pagosVisibles: [Pago] {
        let t = busqueda.trimmingCharacters(in: .whitespaces)
        return pagos.filter { p in
            (filtroInquilino == nil || p.inquilino.id == filtroInquilino)
                && (t.isEmpty || p.inquilino.nombre.localizedStandardContains(t) || p.piso.direccion.localizedStandardContains(t)
                    || String(p.numeroHabitacion) == t)
        }
    }

    var totalVisible: Decimal { pagosVisibles.reduce(0) { $0 + $1.cantidad } }

    /// Inquilinos con pagos o pendientes en el mes, para el filtro.
    var inquilinosDelMes: [InquilinoBreve] {
        var vistos = Set<Int>()
        return (pagos.map(\.inquilino) + (resumen.valor?.pendientes.map(\.inquilino) ?? []))
            .filter { vistos.insert($0.id).inserted }
            .sorted { $0.nombre.localizedStandardCompare($1.nombre) == .orderedAscending }
    }

    func cargar(con api: APIClient) async {
        if resumen.valor == nil { resumen = .cargando }
        do {
            async let r = api.enviar(.resumenPagos(mes: mes))
            async let p = api.enviar(.pagos(mes: mes))
            let (nuevoResumen, nuevosPagos) = try await (r, p)
            resumen = .cargado(nuevoResumen)
            pagos = nuevosPagos
            if let f = filtroInquilino, !inquilinosDelMes.contains(where: { $0.id == f }) { filtroInquilino = nil }
        } catch let e as APIError {
            if case .noAutorizado = e { return }
            if resumen.valor == nil { resumen = .error(e.localizedDescription) } else { error = e.localizedDescription }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func cambiarMes(_ nuevo: Mes, con api: APIClient) async {
        mes = nuevo
        resumen = .cargando
        await cargar(con: api)
    }

    func borrar(_ p: Pago, con api: APIClient) async {
        do {
            _ = try await api.enviar(.borrarPago(id: p.id))
            await cargar(con: api)
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
