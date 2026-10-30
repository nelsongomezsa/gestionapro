import SwiftUI

struct IncidenciasView: View {
    var body: some View {
        NavigationStack {
            PantallaPendiente(titulo: "Incidencias", fase: "4E")
                .navigationTitle("Incidencias")
        }
    }
}
