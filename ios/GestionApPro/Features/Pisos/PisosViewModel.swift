import Foundation
import Observation

@MainActor
@Observable
final class PisosViewModel {
    enum Estado: Equatable {
        case cargando
        case vacio
        case cargado([Piso])
        case error(String)
    }

    private(set) var estado: Estado = .cargando

    func cargar(con api: APIClient) async {
        // En un pull-to-refresh se mantiene la lista mientras llega la nueva.
        if case .cargado = estado {} else { estado = .cargando }
        do {
            let pisos = try await api.enviar(.pisos)
            estado = pisos.isEmpty ? .vacio : .cargado(pisos)
        } catch .noAutorizado {
            // La sesión ya vuelve al login.
        } catch {
            estado = .error(error.localizedDescription)
        }
    }
}
