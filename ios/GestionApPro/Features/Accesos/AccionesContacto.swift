import SwiftUI

/// Llamar, WhatsApp y email para los menús contextuales (mantener pulsado una fila).
struct AccionesContacto: View {
    @Environment(\.openURL) private var abrir
    let telefono: String?
    let email: String?

    var body: some View {
        if let t = telefono, let url = Contacto.llamada(t) {
            Button("Llamar", systemImage: "phone") { abrir(url) }
        }
        if let t = telefono, let url = Contacto.whatsApp(t) {
            Button("WhatsApp", systemImage: "message") { abrir(url) }
        }
        if let e = email, let url = Contacto.email(e) {
            Button("Email", systemImage: "envelope") { abrir(url) }
        }
    }
}
