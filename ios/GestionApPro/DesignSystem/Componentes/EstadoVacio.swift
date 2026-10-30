import SwiftUI

/// Pantalla de vacío o error, con acción opcional.
struct EstadoVacio: View {
    let icono: String
    let titulo: String
    var mensaje: String? = nil
    var accionTitulo: String? = nil
    var accion: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(titulo, systemImage: icono)
        } description: {
            if let mensaje { Text(mensaje) }
        } actions: {
            if let accionTitulo, let accion {
                Button(accionTitulo, action: accion)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    static func error(_ mensaje: String, reintentar: @escaping () -> Void) -> EstadoVacio {
        EstadoVacio(icono: "exclamationmark.triangle", titulo: "No se pudo cargar",
                    mensaje: mensaje, accionTitulo: "Reintentar", accion: reintentar)
    }
}

/// Estado de una carga asíncrona.
enum EstadoCarga<Valor> {
    case cargando
    case cargado(Valor)
    case error(String)

    var valor: Valor? {
        if case let .cargado(v) = self { return v }
        return nil
    }
}

extension EstadoCarga: Equatable where Valor: Equatable {}

/// Muestra carga, error (con reintentar) o el contenido.
struct VistaCarga<Valor, Contenido: View>: View {
    let estado: EstadoCarga<Valor>
    let reintentar: () -> Void
    @ViewBuilder let contenido: (Valor) -> Contenido

    var body: some View {
        switch estado {
        case .cargando:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Cargando")
        case let .error(mensaje):
            ScrollView { EstadoVacio.error(mensaje, reintentar: reintentar) }
        case let .cargado(valor):
            contenido(valor)
        }
    }
}
