import SwiftUI

struct CobrosView: View {
    var body: some View {
        NavigationStack {
            PantallaPendiente(titulo: "Cobros", fase: "4C")
                .navigationTitle("Cobros")
        }
    }
}
