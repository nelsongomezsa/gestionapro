import SwiftUI

/// Bienvenida breve la primera vez que un propietario entra tras la actualización: tres novedades
/// y a trabajar. No se muestra en los tests de UI (`-reiniciarSesion`).
struct BienvenidaView: View {
    static let clave = "bienvenida.vista.v2"
    @Environment(\.dismiss) private var cerrar

    static func debeMostrarse(vista: Bool, argumentos: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        !vista && !argumentos.contains("-reiniciarSesion")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.l) {
            Text("Novedades de GestionAp")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Tema.Color.texto)
                .padding(.top, Tema.Espacio.l)
            punto("hand.tap", "Todo a mano", "Cobrar, comunicar una incidencia, apuntar un gasto o abrir Mensajes desde la barra de abajo, en cualquier pantalla.")
            punto("sparkles", "Asistente que sabe dónde estás", "Si lo activas en el servidor, el botón flotante pregunta sobre el inmueble o contrato que tengas abierto. Puedes ocultarlo en Perfil.")
            punto("hand.point.up.left", "Mantén pulsado", "En cobros, inquilinos e inmuebles: llamar, escribir por WhatsApp, registrar el pago o abrir en Mapas.")
            Spacer()
            Button { cerrar() } label: {
                Text("Empezar").font(.headline).frame(maxWidth: .infinity).frame(minHeight: 50)
            }
            .buttonStyle(.glassProminent)
            .tint(Tema.Color.primarioRelleno)
            .accessibilityIdentifier("botonEmpezar")
        }
        .padding(Tema.Espacio.l)
        .background(Tema.Color.fondo)
        .interactiveDismissDisabled(false)
    }

    private func punto(_ icono: String, _ titulo: String, _ texto: String) -> some View {
        HStack(alignment: .top, spacing: Tema.Espacio.m) {
            Image(systemName: icono)
                .font(.title2)
                .foregroundStyle(Tema.Color.primario)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(titulo).font(.headline).foregroundStyle(Tema.Color.texto)
                Text(texto).font(.subheadline).foregroundStyle(Tema.Color.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
