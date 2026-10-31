import SwiftUI

/// Lo que el usuario tiene abierto (piso o contrato). La burbuja del asistente lo manda con la
/// pregunta para que la respuesta hable de eso; la API comprueba que el usuario puede verlo.
enum ContextoPantalla: Equatable, Sendable {
    case piso(Int)
    case contrato(Int)

    var paraAPI: PreguntaAsistente.Contexto {
        switch self {
        case let .piso(id): .init(tipo: "PISO", id: id)
        case let .contrato(id): .init(tipo: "CONTRATO", id: id)
        }
    }

    var descripcion: String {
        switch self {
        case .piso: "este piso"
        case .contrato: "este contrato"
        }
    }
}

/// Pantalla abierta ahora mismo. La declaran el detalle de piso y el de contrato al aparecer y la
/// retiran al desaparecer (también al cambiar de pestaña), así nunca se cuela la de otra pestaña.
@MainActor
@Observable
final class PantallaActual {
    var contexto: ContextoPantalla?
}

private struct DeclararContexto: ViewModifier {
    @Environment(PantallaActual.self) private var pantalla: PantallaActual?
    let contexto: ContextoPantalla

    func body(content: Content) -> some View {
        content
            .onAppear { pantalla?.contexto = contexto }
            .onDisappear { if pantalla?.contexto == contexto { pantalla?.contexto = nil } }
    }
}

extension View {
    /// Declara el contexto de esta pantalla para el asistente flotante.
    func contextoAsistente(_ contexto: ContextoPantalla) -> some View {
        modifier(DeclararContexto(contexto: contexto))
    }
}
