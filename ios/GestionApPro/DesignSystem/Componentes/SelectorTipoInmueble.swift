import SwiftUI

/// Filtro "Todos · Vivienda · Garaje · Trasteros" (Pisos, Cobros y Estadísticas).
/// Solo tiene sentido si la cartera mezcla tipos: quien lo usa decide cuándo mostrarlo.
struct SelectorTipoInmueble: View {
    @Binding var tipo: TipoInmueble?

    var body: some View {
        Picker("Tipo de inmueble", selection: $tipo.animation(Tema.Movimiento.suave)) {
            Text("Todos").tag(TipoInmueble?.none)
            ForEach(TipoInmueble.allCases) { Text($0.nombre).tag(TipoInmueble?.some($0)) }
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: tipo)
        .accessibilityIdentifier("selectorTipoInmueble")
    }
}
