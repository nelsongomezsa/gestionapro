import Foundation
import Observation

@MainActor
@Observable
final class InquilinosViewModel {
    private(set) var estado: EstadoCarga<[Inquilino]> = .cargando
    var busqueda = ""
    var soloConContrato = false
    var error: String?

    /// Búsqueda como en el escritorio: nombre, apellidos, DNI, teléfono o email.
    var visibles: [Inquilino] {
        let t = busqueda.trimmingCharacters(in: .whitespaces)
        return (estado.valor ?? []).filter { i in
            (!soloConContrato || i.contratoActivo != nil)
                && (t.isEmpty || i.nombreCompleto.localizedStandardContains(t) || i.dni.localizedStandardContains(t)
                    || (i.telefono?.filter(\.isNumber).contains(t.filter(\.isNumber)) ?? false) && !t.filter(\.isNumber).isEmpty
                    || (i.email?.localizedStandardContains(t) ?? false))
        }
    }

    func cargar(con api: APIClient) async {
        if estado.valor == nil { estado = .cargando }
        do {
            estado = .cargado(try await api.enviar(.inquilinos))
        } catch .noAutorizado {
        } catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) } else { self.error = error.localizedDescription }
        }
    }

    func borrar(_ i: Inquilino, con api: APIClient) async {
        do {
            _ = try await api.enviar(.borrarInquilino(id: i.id))
            if case var .cargado(lista) = estado {
                lista.removeAll { $0.id == i.id }
                estado = .cargado(lista)
            }
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    func pdf() -> DocumentoPDF {
        let columnas: [GeneradorPDF.Columna] = [
            .init(titulo: "Nombre", peso: 2.2), .init(titulo: "DNI", peso: 1.1), .init(titulo: "Teléfono", peso: 1.2),
            .init(titulo: "Email", peso: 2.2), .init(titulo: "Habitación", peso: 2.0),
        ]
        let filas = visibles.map { i in
            [i.nombreCompleto, i.dni, i.telefono ?? "—", i.email ?? "—",
             i.contratoActivo.map { "Hab. \($0.numeroHabitacion) · \($0.piso.direccion)" } ?? "Sin contrato activo"]
        }
        return DocumentoPDF(titulo: "Inquilinos",
                            datos: GeneradorPDF.tabla(titulo: "Inquilinos", subtitulo: "\(filas.count) inquilinos",
                                                      columnas: columnas, filas: filas))
    }
}
