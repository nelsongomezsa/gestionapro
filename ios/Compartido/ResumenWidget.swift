import Foundation

/// Lo que muestra el widget de Inicio. La app lo guarda al cargar Inicio en el App Group compartido;
/// el widget solo lo lee (no tiene sesión ni hace peticiones).
struct ResumenWidget: Codable, Sendable {
    static let grupo = "group.com.gestionap.GestionApPro"
    static let clave = "resumenWidget"

    let mes: String
    let cobrado: Decimal
    let esperado: Decimal
    let pendientes: Int
    let incidenciasAbiertas: Int
    let actualizado: Date

    var progreso: Double {
        esperado > 0 ? min(1, NSDecimalNumber(decimal: cobrado / esperado).doubleValue) : 0
    }

    static func leer() -> ResumenWidget? {
        guard let datos = UserDefaults(suiteName: grupo)?.data(forKey: clave) else { return nil }
        return try? JSONDecoder().decode(ResumenWidget.self, from: datos)
    }

    func guardar() {
        guard let datos = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.grupo)?.set(datos, forKey: Self.clave)
    }

    static func borrar() {
        UserDefaults(suiteName: grupo)?.removeObject(forKey: clave)
    }
}
