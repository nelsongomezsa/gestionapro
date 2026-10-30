import SwiftUI

/// Tarjeta principal de una pantalla: la cifra que más importa, su contexto y una acción.
/// Va en azul marino en los dos modos; su contenido usa los colores del modo oscuro para
/// mantener el contraste.
struct TarjetaHero<Contenido: View>: View {
    let titulo: String
    let valor: String
    var accesorio: AnyView? = nil
    @ViewBuilder var contenido: Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.m) {
            VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(titulo)
                        .font(Tema.Fuente.detalle)
                        .foregroundStyle(Tema.Color.textoSecundario)
                    Spacer(minLength: Tema.Espacio.xs)
                    accesorio
                }
                Text(valor)
                    .font(Tema.Fuente.cifraHeroe)
                    .foregroundStyle(Tema.Color.texto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            contenido
        }
        .padding(Tema.Espacio.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tema.Color.superficieHeroe, in: .rect(cornerRadius: Tema.Radio.tarjeta))
        .overlay(RoundedRectangle(cornerRadius: Tema.Radio.tarjeta).strokeBorder(Tema.Color.bordeHeroe, lineWidth: 1)
            .allowsHitTesting(false))
        .environment(\.colorScheme, .dark)
    }
}

/// Barra de progreso fina (cobrado frente a esperado, ocupación...).
struct BarraProgreso: View {
    /// Entre 0 y 1; se recorta si se sale.
    let valor: Double
    var tono: Tono = .primario

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Tema.Color.superficieElevada)
                Capsule().fill(tono.color)
                    .frame(width: geo.size.width * min(max(valor, 0), 1))
            }
        }
        .frame(height: Tema.Tamano.alturaBarraProgreso)
        .accessibilityHidden(true)
    }
}

/// Dato secundario dentro de una tarjeta: etiqueta pequeña y cifra.
struct DatoCompacto: View {
    let titulo: String
    let valor: String
    var tono: Tono? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(Tema.Fuente.nota)
                .foregroundStyle(Tema.Color.textoSecundario)
            Text(valor)
                .font(Tema.Fuente.cifraPequena)
                .foregroundStyle(tono?.color ?? Tema.Color.texto)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Botón secundario sobre una tarjeta: texto e icono en el color de acento sobre un fondo suave.
struct BotonSecundario: View {
    let titulo: String
    var icono: String? = nil
    var cargando = false
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: Tema.Espacio.xs) {
                if cargando { ProgressView() } else if let icono { Image(systemName: icono) }
                Text(titulo)
            }
            .font(Tema.Fuente.detalle.weight(.semibold))
            .foregroundStyle(Tema.Color.primario)
            .padding(.horizontal, Tema.Espacio.m)
            .frame(minHeight: 40)
            .background(Tema.Color.primarioSuave, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(cargando)
    }
}

#Preview {
    VStack(spacing: Tema.Espacio.m) {
        TarjetaHero(titulo: "Cobrado este mes", valor: "5.730,00 €") {
            BarraProgreso(valor: 0.67, tono: .positivo)
            HStack {
                DatoCompacto(titulo: "Esperado", valor: "8.540,00 €")
                Spacer()
                DatoCompacto(titulo: "Pendiente", valor: "2.810,00 €", tono: .aviso)
            }
            BotonSecundario(titulo: "Informe del mes", icono: "doc.richtext") {}
        }
    }
    .padding()
    .background(Tema.Color.fondo)
}
