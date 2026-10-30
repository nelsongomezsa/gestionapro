import Foundation
import Observation

/// Totales de la cartera calculados a partir de la lista de pisos.
struct ResumenCartera: Equatable {
    let ingresosMensuales: Decimal
    let cashFlowMensual: Decimal
    let habitaciones: Int
    let alquiladas: Int
    let disponibles: Int
    let pisosSinDatos: Int

    var ocupacion: Double { habitaciones > 0 ? Double(alquiladas) / Double(habitaciones) : 0 }

    init(_ pisos: [Piso]) {
        ingresosMensuales = pisos.reduce(0) { $0 + $1.ingresosMensuales }
        cashFlowMensual = pisos.reduce(0) { $0 + ($1.metricas?.cashFlowMensual ?? 0) }
        habitaciones = pisos.reduce(0) { $0 + $1.ocupacion.total }
        alquiladas = pisos.reduce(0) { $0 + $1.ocupacion.alquiladas }
        disponibles = pisos.reduce(0) { $0 + $1.ocupacion.disponibles }
        pisosSinDatos = pisos.filter { $0.metricas == nil }.count
    }
}

@MainActor
@Observable
final class PisosViewModel {

    enum Orden: String, CaseIterable, Identifiable {
        case cashFlow = "Cash flow"
        case rentabilidad = "Rentabilidad"
        case ocupacion = "Ocupación"
        case direccion = "Dirección"
        var id: Self { self }
    }

    private(set) var estado: EstadoCarga<[Piso]> = .cargando
    var busqueda = ""
    var ciudad: String?
    var orden: Orden = .cashFlow

    var ciudades: [String] {
        Array(Set((estado.valor ?? []).map(\.ciudad.nombre))).sorted()
    }

    var resumen: ResumenCartera { ResumenCartera(estado.valor ?? []) }

    /// Pisos tras buscar (dirección o ciudad, sin tildes ni mayúsculas), filtrar y ordenar.
    var pisosVisibles: [Piso] {
        let texto = busqueda.trimmingCharacters(in: .whitespaces)
        return (estado.valor ?? [])
            .filter { ciudad == nil || $0.ciudad.nombre == ciudad }
            .filter {
                texto.isEmpty
                    || $0.direccion.localizedStandardContains(texto)
                    || $0.ciudad.nombre.localizedStandardContains(texto)
            }
            .sorted(by: comparador)
    }

    private var comparador: (Piso, Piso) -> Bool {
        switch orden {
        case .cashFlow:
            { ($0.metricas?.cashFlowMensual ?? -.greatestFiniteMagnitude) > ($1.metricas?.cashFlowMensual ?? -.greatestFiniteMagnitude) }
        case .rentabilidad:
            { ($0.metricas?.rentabilidadBrutaPct ?? -.infinity) > ($1.metricas?.rentabilidadBrutaPct ?? -.infinity) }
        case .ocupacion:
            { Self.ocupacion($0) > Self.ocupacion($1) }
        case .direccion:
            { $0.direccion.localizedStandardCompare($1.direccion) == .orderedAscending }
        }
    }

    private static func ocupacion(_ p: Piso) -> Double {
        p.ocupacion.total > 0 ? Double(p.ocupacion.alquiladas) / Double(p.ocupacion.total) : 0
    }

    func cargar(con api: APIClient) async {
        if estado.valor == nil { estado = .cargando }
        do {
            estado = .cargado(try await api.enviar(.pisos))
        } catch .noAutorizado {
            // La sesión ya vuelve al login.
        } catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) }
        }
    }
}
