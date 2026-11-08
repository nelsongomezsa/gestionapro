import SwiftUI

/// Tarjeta de un piso: dirección completa, semáforo, ocupación y cash flow.
struct TarjetaPiso: View {
    @Environment(\.dynamicTypeSize) private var tamanoTexto
    let piso: Piso

    private var ocupacion: Double {
        piso.ocupacion.total > 0 ? Double(piso.ocupacion.alquiladas) / Double(piso.ocupacion.total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.m) {
            HStack(alignment: .top, spacing: Tema.Espacio.s) {
                IconoEtiqueta(icono: "building.2", tono: .primario)
                VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                    Text(piso.direccion)
                        .font(Tema.Fuente.subtitulo)
                        .foregroundStyle(Tema.Color.texto)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(piso.ciudad.nombre)
                        .font(Tema.Fuente.detalle)
                        .foregroundStyle(Tema.Color.textoSecundario)
                    // Con texto grande la insignia va debajo: a la derecha se partía ("Exce-lente").
                    if tamanoTexto.isAccessibilitySize {
                        piso.metricas?.calificacion.insignia ?? Calificacion?.none.insignia
                    }
                }
                Spacer(minLength: Tema.Espacio.xs)
                if !tamanoTexto.isAccessibilitySize {
                    piso.metricas?.calificacion.insignia ?? Calificacion?.none.insignia
                }
            }

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                    Text("Cash flow previsto")
                        .font(Tema.Fuente.nota)
                        .foregroundStyle(Tema.Color.textoSecundario)
                    if let m = piso.metricas {
                        Text(Formato.euros(m.cashFlowMensual))
                            .font(Tema.Fuente.cifra)
                            .foregroundStyle(Tono.signo(m.cashFlowMensual).color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text("Sin datos financieros")
                            .font(Tema.Fuente.detalle)
                            .foregroundStyle(Tema.Color.textoSecundario)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Tema.Espacio.linea) {
                    Text("Rentabilidad bruta")
                        .font(Tema.Fuente.nota)
                        .foregroundStyle(Tema.Color.textoSecundario)
                    Text(Formato.porcentaje(piso.metricas?.rentabilidadBrutaPct))
                        .font(Tema.Fuente.cifraPequena)
                        .foregroundStyle(Tema.Color.texto)
                }
            }

            VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                BarraProgreso(valor: ocupacion, tono: Tono.ocupacion(ocupacion * 100))
                Text(piso.tipoInmueble.unidad.alquiladas(piso.ocupacion.alquiladas, de: piso.ocupacion.total))
                    .font(Tema.Fuente.nota)
                    .foregroundStyle(Tema.Color.textoSecundario)
            }
        }
        .tarjeta()
        .accessibilityElement(children: .combine)
    }
}
