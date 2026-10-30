import SwiftUI

/// Botón de acción principal, a todo el ancho, con estado de carga.
struct BotonPrincipal: View {
    let titulo: String
    var icono: String? = nil
    var cargando = false
    var destructivo = false
    let accion: () -> Void

    @Environment(\.isEnabled) private var habilitado

    var body: some View {
        Button(action: accion) {
            HStack(spacing: Tema.Espacio.xs) {
                if cargando {
                    ProgressView().tint(Tema.Color.sobrePrimario)
                } else {
                    if let icono { Image(systemName: icono) }
                    Text(titulo)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: Tema.Tamano.alturaBoton)
            .foregroundStyle(Tema.Color.sobrePrimario)
            .background((destructivo ? Tema.Color.negativoRelleno : Tema.Color.primarioRelleno).opacity(habilitado ? 1 : 0.4),
                        in: .rect(cornerRadius: Tema.Radio.medio))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(cargando)
        .accessibilityLabel(cargando ? "\(titulo), cargando" : titulo)
    }
}

#Preview {
    VStack {
        BotonPrincipal(titulo: "Iniciar sesión", accion: {})
        BotonPrincipal(titulo: "Guardar", cargando: true, accion: {})
        BotonPrincipal(titulo: "Eliminar", icono: "trash", destructivo: true, accion: {})
    }
    .padding()
}
