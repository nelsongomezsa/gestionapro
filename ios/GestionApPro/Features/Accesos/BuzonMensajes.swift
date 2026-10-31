import Foundation
import Observation

/// Mensajes sin leer de todas las conversaciones. Se consulta al abrir la app, al volver a ella y
/// cada minuto mientras está abierta; si sube el número, `nuevo` trae la conversación para avisar.
@MainActor
@Observable
final class BuzonMensajes {
    private(set) var sinLeer = 0
    /// Última conversación con mensajes nuevos desde la consulta anterior (para el aviso).
    var nuevo: Conversacion?
    private var primeraCarga = true

    func actualizar(con api: APIClient) async {
        guard let conversaciones = try? await api.enviar(.conversaciones) else { return }
        aplicar(conversaciones)
    }

    /// Separado de la red para poder probarlo.
    func aplicar(_ conversaciones: [Conversacion]) {
        let total = conversaciones.reduce(0) { $0 + Int($1.sinLeer) }
        if !primeraCarga, total > sinLeer {
            nuevo = conversaciones.filter { $0.sinLeer > 0 && !$0.ultimoMio }.max { $0.fecha < $1.fecha }
        }
        sinLeer = total
        primeraCarga = false
    }
}
