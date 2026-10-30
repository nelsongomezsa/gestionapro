import Foundation
import Observation

@MainActor
@Observable
final class HabitacionesViewModel {
    let piso: PisoBreve
    private(set) var estado: EstadoCarga<[Habitacion]> = .cargando
    var filtro: EstadoHabitacion?
    var busqueda = ""
    var error: String?

    init(piso: PisoBreve) {
        self.piso = piso
    }

    var visibles: [Habitacion] {
        let t = busqueda.trimmingCharacters(in: .whitespaces)
        return (estado.valor ?? []).filter { h in
            (filtro == nil || h.estado == filtro)
                && (t.isEmpty || String(h.numero) == t || (h.inquilinoActual?.nombre.localizedStandardContains(t) ?? false))
        }
    }

    func cuenta(_ e: EstadoHabitacion?) -> Int {
        (estado.valor ?? []).filter { e == nil || $0.estado == e }.count
    }

    func cargar(con api: APIClient) async {
        if estado.valor == nil { estado = .cargando }
        do {
            estado = .cargado(try await api.enviar(.habitaciones(piso: piso.id)))
        } catch .noAutorizado {
        } catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) } else { self.error = error.localizedDescription }
        }
    }

    func cambiarEstado(_ h: Habitacion, a nuevo: EstadoHabitacion, con api: APIClient) async {
        do {
            reemplazar(try await api.enviar(.cambiarEstado(habitacion: h.id, a: nuevo)))
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    func borrar(_ h: Habitacion, con api: APIClient) async {
        do {
            _ = try await api.enviar(.borrarHabitacion(id: h.id))
            if case var .cargado(lista) = estado {
                lista.removeAll { $0.id == h.id }
                estado = .cargado(lista)
            }
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reemplazar(_ h: Habitacion) {
        guard case var .cargado(lista) = estado else { return }
        if let i = lista.firstIndex(where: { $0.id == h.id }) { lista[i] = h } else { lista.append(h) }
        estado = .cargado(lista.sorted { $0.numero < $1.numero })
    }

    func pdf() -> DocumentoPDF {
        let columnas: [GeneradorPDF.Columna] = [
            .init(titulo: "Hab.", peso: 0.6), .init(titulo: "Precio", peso: 1.1, alineacion: .right),
            .init(titulo: "Estado", peso: 1.2), .init(titulo: "Inquilino actual", peso: 2.4),
            .init(titulo: "Días", peso: 0.7, alineacion: .right),
        ]
        let filas = visibles.map { h in
            ["\(h.numero)", Formato.euros(h.precio), h.estado.nombre, h.inquilinoActual?.nombre ?? "—",
             h.diasAlquilada.map { "\($0)" } ?? "—"]
        }
        let datos = GeneradorPDF.tabla(titulo: "Habitaciones", subtitulo: "\(piso.direccion) · \(piso.ciudad)",
                                       columnas: columnas, filas: filas)
        return DocumentoPDF(titulo: "Habitaciones \(piso.direccion)", datos: datos)
    }
}
