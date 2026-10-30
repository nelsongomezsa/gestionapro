import Foundation
import Observation

@MainActor
@Observable
final class ContratosViewModel {
    private(set) var estado: EstadoCarga<[Contrato]> = .cargando
    var filtro: FiltroContratos = .activos
    var busqueda = ""
    var error: String?

    var visibles: [Contrato] {
        let t = busqueda.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return estado.valor ?? [] }
        return (estado.valor ?? []).filter {
            $0.inquilino.nombre.localizedStandardContains(t) || $0.piso.direccion.localizedStandardContains(t)
                || $0.piso.ciudad.localizedStandardContains(t)
        }
    }

    func cargar(con api: APIClient) async {
        if estado.valor == nil { estado = .cargando }
        do {
            estado = .cargado(try await api.enviar(.contratos(filtro: filtro)))
        } catch .noAutorizado {
        } catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) } else { self.error = error.localizedDescription }
        }
    }

    func finalizar(_ c: Contrato, con api: APIClient) async {
        do {
            _ = try await api.enviar(.finalizarContrato(id: c.id))
            await cargar(con: api)
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    func pdf() -> DocumentoPDF {
        let f = Date.FormatStyle.dateTime.day().month(.twoDigits).year().locale(Formato.locale)
        let columnas: [GeneradorPDF.Columna] = [
            .init(titulo: "Inquilino", peso: 2), .init(titulo: "Habitación", peso: 2.2),
            .init(titulo: "Inicio", peso: 1), .init(titulo: "Fin", peso: 1),
            .init(titulo: "Renta", peso: 1, alineacion: .right), .init(titulo: "Estado", peso: 1.2),
        ]
        let filas = visibles.map { c in
            [c.inquilino.nombre, "Hab. \(c.habitacion.numero) · \(c.piso.direccion)", c.fechaInicio.formatted(f),
             c.fechaFin.formatted(f), Formato.euros(c.precioMensual), c.activo ? c.vencimiento.texto : "Finalizado"]
        }
        return DocumentoPDF(titulo: "Contratos", datos: GeneradorPDF.tabla(
            titulo: "Contratos", subtitulo: "\(filtro.nombre) · \(filas.count) contratos", columnas: columnas, filas: filas))
    }
}

/// Texto del recordatorio de pago del escritorio (ContratosController.enviarRecordatorio).
enum Recordatorio {
    static func asunto(_ c: Contrato) -> String { "Recordatorio de pago - \(c.inquilino.nombre)" }

    static func cuerpo(_ c: Contrato) -> String {
        "Estimado/a \(c.inquilino.nombre),\n\n"
            + "Le recordamos que el próximo pago de su arrendamiento de la habitación \(c.habitacion.numero) "
            + "en \(c.piso.direccion) está pendiente.\n\n"
            + "Importe mensual: \(Formato.euros(c.precioMensual))\n"
            + "Fecha fin de contrato: \(c.fechaFin.formatted(.dateTime.day().month(.wide).year().locale(Formato.locale)))\n\n"
            + "Gracias por su colaboración."
    }
}
