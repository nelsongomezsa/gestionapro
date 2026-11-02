import SwiftUI

/// Lo que el usuario tiene abierto (piso o contrato). La burbuja del asistente lo manda con la
/// pregunta para que la respuesta hable de eso; la API comprueba que el usuario puede verlo.
enum ContextoPantalla: Equatable, Sendable {
    case piso(Int)
    case contrato(Int)
    case inquilino(Int)

    var paraAPI: PreguntaAsistente.Contexto {
        switch self {
        case let .piso(id): .init(tipo: "PISO", id: id)
        case let .contrato(id): .init(tipo: "CONTRATO", id: id)
        case let .inquilino(id): .init(tipo: "INQUILINO", id: id)
        }
    }

    var descripcion: String {
        switch self {
        case .piso: String(localized: "este piso")
        case .contrato: String(localized: "este contrato")
        case .inquilino: String(localized: "este inquilino")
        }
    }
}

/// Pantalla abierta ahora mismo. La declaran el detalle de piso y el de contrato al aparecer y la
/// retiran al desaparecer (también al cambiar de pestaña), así nunca se cuela la de otra pestaña.
@MainActor
@Observable
final class PantallaActual {
    var contexto: ContextoPantalla?
    /// Pantallas abiertas que llevan su propia barra abajo (el chat): mientras haya alguna, se oculta
    /// la barra de pestañas, como en Mensajes.
    var sinBarra = 0
    /// Pantallas donde no tiene sentido el botón «+» (Ajustes, Asistente).
    var sinCrear = 0
}

private struct OcultarBotonCrear: ViewModifier {
    @Environment(PantallaActual.self) private var pantalla: PantallaActual?
    func body(content: Content) -> some View {
        content
            .onAppear { pantalla?.sinCrear += 1 }
            .onDisappear { pantalla.map { $0.sinCrear = max(0, $0.sinCrear - 1) } }
    }
}

extension View {
    /// Oculta el botón «+» de la barra mientras esta pantalla está abierta.
    func sinBotonCrear() -> some View { modifier(OcultarBotonCrear()) }
}

private struct OcultarBarraPestanas: ViewModifier {
    @Environment(PantallaActual.self) private var pantalla: PantallaActual?
    func body(content: Content) -> some View {
        content
            .onAppear { pantalla?.sinBarra += 1 }
            .onDisappear { pantalla.map { $0.sinBarra = max(0, $0.sinBarra - 1) } }
    }
}

extension View {
    /// Oculta la barra de pestañas mientras esta pantalla está abierta.
    func sinBarraDePestanas() -> some View { modifier(OcultarBarraPestanas()) }
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
    /// Declara el contexto de esta pantalla para el asistente (lengüeta).
    func contextoAsistente(_ contexto: ContextoPantalla) -> some View {
        modifier(DeclararContexto(contexto: contexto))
    }
}
