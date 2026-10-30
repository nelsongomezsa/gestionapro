import SwiftUI

/// Fila "etiqueta ……… valor" para listas de métricas.
struct FilaMetrica: View {
    let titulo: String
    let valor: String
    var nota: String? = nil
    var tono: Tono? = nil
    var icono: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.s) {
            if let icono {
                Image(systemName: icono)
                    .foregroundStyle(Tema.Color.primario)
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(titulo)
                if let nota {
                    Text(nota)
                        .font(Tema.Fuente.nota)
                        .foregroundStyle(Tema.Color.textoSecundario)
                }
            }
            Spacer(minLength: Tema.Espacio.s)
            Text(valor)
                .font(Tema.Fuente.cifraPequena)
                .foregroundStyle(tono?.color ?? .primary)
                .multilineTextAlignment(.trailing)
        }
        // Toda la fila es tocable, también el hueco del Spacer (importa cuando va dentro de un
        // NavigationLink o Button con estilo .plain, que solo responde donde hay contenido).
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
