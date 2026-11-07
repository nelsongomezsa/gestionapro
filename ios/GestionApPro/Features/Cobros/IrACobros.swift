import Observation

/// Abrir la pestaña Cobros en un mes concreto desde otra pantalla (la tarjeta de Inicio).
/// RaizView cambia de pestaña al ver un mes pedido; CobrosView lo carga y lo deja en nil.
@MainActor
@Observable
final class IrACobros {
    var mes: Mes?
}

/// Abrir un piso en la pestaña Pisos (el creado desde el «+» general).
@MainActor
@Observable
final class IrAPiso {
    var piso: Piso?
}
