import Foundation
import Observation

@MainActor
@Observable
final class CalculadoraViewModel {
    /// Valores iniciales: un caso típico, para que la pantalla no empiece vacía.
    var entrada = RentabilidadRequest(
        comunidad: "Madrid", precioCompra: 200_000, gastosNotariaRegistro: 2_500, gastosHipoteca: 1_500,
        reforma: 10_000, comisionCompra: 3_000, mobiliario: 4_000,
        ibiMensual: 50, segurosMensual: 30, comunidadMensual: 80, mantenimientoMensual: 40, vacioMensual: 60,
        alquilerMensual: 1_400, revalorizacionAnualPct: 3, porcentajeFinanciado: 80, plazoAnos: 25,
        tipoInteresPct: 3.2)

    private(set) var comunidades: [ItpResponse.Comunidad] = []
    private(set) var anioReferenciaItp: String?
    private(set) var calculando = false
    private(set) var error: String?
    var resultado: RentabilidadResponse?

    var tipoItpSeleccionado: Double? {
        comunidades.first { $0.nombre == entrada.comunidad }?.tipoPct
    }

    func cargarComunidades(con api: APIClient) async {
        guard comunidades.isEmpty else { return }
        do {
            let itp = try await api.enviar(.itp)
            comunidades = itp.comunidades
            anioReferenciaItp = itp.anioReferencia
            if !comunidades.contains(where: { $0.nombre == entrada.comunidad }), let primera = comunidades.first {
                entrada.comunidad = primera.nombre
            }
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    func calcular(con api: APIClient) async {
        calculando = true
        error = nil
        defer { calculando = false }
        do {
            resultado = try await api.enviar(.rentabilidad(entrada))
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
