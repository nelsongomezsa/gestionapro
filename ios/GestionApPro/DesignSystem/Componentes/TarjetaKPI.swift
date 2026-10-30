import SwiftUI

/// Indicador clave: icono, etiqueta, cifra grande y, opcionalmente, tendencia o detalle.
struct TarjetaKPI: View {
    let titulo: String
    let valor: String
    var icono: String
    var tono: Tono = .primario
    var detalle: String? = nil
    /// Variación en % respecto a otro periodo (p. ej. 4.5 = +4,5 %).
    var tendencia: Double? = nil
    /// Con qué se compara la tendencia ("2025"): toda cifra comparativa lo dice.
    var frenteA: String = ""

    @Environment(\.dynamicTypeSize) private var tamanoTexto

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.s) {
            IconoEtiqueta(icono: icono, tono: tono, tamano: Tema.Tamano.iconoPequeno)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(valor)
                    .font(Tema.Fuente.cifra)
                    .foregroundStyle(Tema.Color.texto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                // Con texto grande de accesibilidad, el título pasa a varias líneas en vez de encogerse.
                Text(titulo)
                    .font(Tema.Fuente.detalle.weight(.medium))
                    .foregroundStyle(Tema.Color.texto)
                    .lineLimit(tamanoTexto.isAccessibilitySize ? 3 : 1)
                    .minimumScaleFactor(0.8)
                if let tendencia {
                    InsigniaEstado(texto: frenteA.isEmpty ? Formato.porcentaje(abs(tendencia))
                                                          : "\(Formato.porcentaje(abs(tendencia))) vs. \(frenteA)",
                                   tono: Tono.signo(tendencia),
                                   icono: tendencia >= 0 ? "arrow.up.right" : "arrow.down.right")
                } else if let detalle {
                    Text(detalle)
                        .font(Tema.Fuente.nota)
                        .foregroundStyle(Tema.Color.textoSecundario)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        // Todas las tarjetas de una fila con la misma altura.
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .tarjeta()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
        TarjetaKPI(titulo: "Ingresos del mes", valor: "8.540,00 €", icono: "eurosign", tendencia: 4.2, frenteA: "sept.")
        TarjetaKPI(titulo: "Ocupación", valor: "67 %", icono: "bed.double", tono: .aviso)
    }
    .padding()
    .background(Tema.Color.fondo)
}
