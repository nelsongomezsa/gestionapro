import SwiftUI

/// Indicador clave: icono, etiqueta, cifra grande y, opcionalmente, tendencia o detalle.
struct TarjetaKPI: View {
    let titulo: String
    let valor: String
    var icono: String
    var tono: Tono = .primario
    var detalle: String? = nil
    /// Variación en puntos porcentuales respecto al periodo anterior (p. ej. 4.5 = +4,5 %).
    var tendencia: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            HStack {
                Image(systemName: icono)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tono.color)
                    .frame(width: 30, height: 30)
                    .background(tono.color.opacity(0.14), in: .rect(cornerRadius: Tema.Radio.pequeno))
                    .accessibilityHidden(true)
                Spacer()
                if let tendencia {
                    InsigniaEstado(texto: Formato.porcentaje(abs(tendencia)), tono: Tono.signo(tendencia),
                                   icono: tendencia >= 0 ? "arrow.up.right" : "arrow.down.right")
                }
            }
            Text(valor)
                .font(Tema.Fuente.cifra)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(titulo)
                .font(Tema.Fuente.detalle)
                .foregroundStyle(Tema.Color.textoSecundario)
            if let detalle {
                Text(detalle)
                    .font(Tema.Fuente.nota)
                    .foregroundStyle(Tema.Color.textoSecundario)
            }
        }
        .tarjeta()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
        TarjetaKPI(titulo: "Ingresos del mes", valor: "8.540,00 €", icono: "eurosign", tendencia: 4.2)
        TarjetaKPI(titulo: "Ocupación", valor: "67 %", icono: "bed.double", tono: .aviso)
    }
    .padding()
    .background(Tema.Color.fondo)
}
