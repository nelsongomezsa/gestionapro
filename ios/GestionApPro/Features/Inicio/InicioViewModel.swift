import Foundation
import Observation
import SwiftUI
import WidgetKit

/// Estado y acciones de Inicio: carga del panel, notificaciones sin leer e informe mensual.
/// Los efectos que dependen de la sesión (widget, avisos locales, dispositivo) los decide la vista.
@MainActor
@Observable
final class InicioViewModel {
    var estado: EstadoCarga<Dashboard> = .cargando
    var noLeidas = 0
    var documento: DocumentoPDF?
    var generandoInforme = false
    var error: String?

    /// Cuántas actividades se ven en Inicio; el resto, en "Ver todo".
    static let actividadesVisibles = 4

    /// Carga panel y notificaciones a la vez. Devuelve el panel si llegó (para los efectos posteriores).
    @discardableResult
    func cargar(con api: APIClient) async -> Dashboard? {
        do {
            async let d = api.enviar(.dashboard)
            async let n = api.enviar(.notificacionesNoLeidas)
            let (dashboard, total) = try await (d, n)
            withAnimation(Tema.Movimiento.suave) { estado = .cargado(dashboard) }
            noLeidas = total.total
            return dashboard
        } catch let e as APIError {
            if case .noAutorizado = e { return nil }
            if estado.valor == nil { estado = .error(e.localizedDescription) } else { error = e.localizedDescription }
            return nil
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func contarNoLeidas(con api: APIClient) async {
        if let total = try? await api.enviar(.notificacionesNoLeidas) { noLeidas = total.total }
    }

    func informe(con api: APIClient) async {
        generandoInforme = true
        defer { generandoInforme = false }
        let mes = Mes.actual
        do {
            let datos = try await api.descargar(Rutas.informeMensual, consulta: [URLQueryItem(name: "mes", value: mes.texto)])
            documento = DocumentoPDF(titulo: "Informe \(mes.nombre)", datos: datos)
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// La alerta de ocupación no se muestra: la tarjeta de Ocupación ya lo dice con su color.
    static func alertas(_ d: Dashboard) -> [Alerta] {
        d.alertas.filter { $0.tipo != "OCUPACION" }
    }

    static func saludo(nombre: String?) -> String {
        let primero = nombre?.split(separator: " ").first.map(String.init) ?? ""
        return primero.isEmpty ? String(localized: "Inicio") : String(localized: "Hola, \(primero)")
    }

    /// Guarda el resumen del mes para el widget y le pide que se redibuje.
    static func actualizarWidget(_ d: Dashboard, con api: APIClient) async {
        let resumen = try? await api.enviar(.resumenPagos(mes: .actual))
        ResumenWidget(mes: resumen?.nombreMes.components(separatedBy: " ").first ?? "este mes",
                      cobrado: d.cobradoMes, esperado: d.esperadoMes, pendientes: resumen?.pendientes.count ?? 0,
                      incidenciasAbiertas: d.incidenciasPendientes + d.incidenciasEnProceso, actualizado: .now).guardar()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
