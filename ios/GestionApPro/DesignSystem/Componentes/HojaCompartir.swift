import SwiftUI
import UIKit

/// Hoja de Compartir de iOS (Mail, WhatsApp, Mensajes, Archivos, Imprimir...).
struct HojaCompartir: UIViewControllerRepresentable {
    let elementos: [Any]
    var asunto: String? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: elementos, applicationActivities: nil)
        if let asunto { vc.setValue(asunto, forKey: "subject") }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// Elementos a compartir, identificables para usar con `.sheet(item:)`.
struct Compartible: Identifiable {
    let id = UUID()
    let elementos: [Any]
    var asunto: String? = nil
}

extension View {
    func hojaCompartir(_ compartible: Binding<Compartible?>) -> some View {
        sheet(item: compartible) { c in
            HojaCompartir(elementos: c.elementos, asunto: c.asunto)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
    }
}
