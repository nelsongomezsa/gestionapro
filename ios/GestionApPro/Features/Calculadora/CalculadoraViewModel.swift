import Foundation
import Observation

@MainActor
@Observable
final class CalculadoraViewModel {
    /// Valores iniciales: un caso típico, para que la pantalla no empiece vacía.
    static let ejemplo = RentabilidadRequest(
        comunidad: "Madrid", precioCompra: 200_000, gastosNotariaRegistro: 2_500, gastosHipoteca: 1_500,
        reforma: 10_000, comisionCompra: 3_000, mobiliario: 4_000,
        ibiMensual: 50, segurosMensual: 30, comunidadMensual: 80, mantenimientoMensual: 40, vacioMensual: 60,
        alquilerMensual: 1_400, revalorizacionAnualPct: 3, porcentajeFinanciado: 80, plazoAnos: 25,
        tipoInteresPct: 3.2)

    static let vacio = RentabilidadRequest(
        comunidad: "Madrid", precioCompra: 0, gastosNotariaRegistro: 0, gastosHipoteca: 0, reforma: 0,
        comisionCompra: 0, mobiliario: 0, ibiMensual: 0, segurosMensual: 0, comunidadMensual: 0,
        mantenimientoMensual: 0, vacioMensual: 0, alquilerMensual: 0, revalorizacionAnualPct: 0,
        porcentajeFinanciado: 0, plazoAnos: 0, tipoInteresPct: 0)

    var entrada = ejemplo
    private(set) var comunidades: [ItpResponse.Comunidad] = []
    private(set) var calculando = false
    private(set) var error: String?
    /// Último resultado: alimenta el resumen en vivo y la pantalla de desglose.
    private(set) var resultado: RentabilidadResponse?
    var mostrarDesglose = false
    /// Cambia al pulsar "Limpiar", para que los campos de texto se rehagan.
    private(set) var version = 0

    var tipoItpSeleccionado: Double? {
        comunidades.first { $0.nombre == entrada.comunidad }?.tipoPct
    }

    func cargarComunidades(con api: APIClient) async {
        guard comunidades.isEmpty else { return }
        do {
            comunidades = try await api.enviar(.itp).comunidades
            if !comunidades.contains(where: { $0.nombre == entrada.comunidad }), let primera = comunidades.first {
                entrada.comunidad = primera.nombre
            }
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Recalcula tras una breve pausa al escribir. Si llega otra pulsación, SwiftUI cancela
    /// esta tarea (`.task(id:)`) y solo se hace la última petición.
    func recalcularConPausa(con api: APIClient) async {
        do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
        await calcular(con: api)
    }

    func calcular(con api: APIClient) async {
        calculando = true
        defer { calculando = false }
        do {
            let r = try await api.enviar(.rentabilidad(entrada))
            guard !Task.isCancelled else { return }
            resultado = r
            error = nil
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    func limpiar() {
        let comunidad = entrada.comunidad
        entrada = Self.vacio
        entrada.comunidad = comunidad
        version += 1
    }
}
