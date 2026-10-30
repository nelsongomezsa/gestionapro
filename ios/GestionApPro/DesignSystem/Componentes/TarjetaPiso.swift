import SwiftUI

/// Tarjeta de un piso: dirección completa, semáforo, ocupación y cash flow.
struct TarjetaPiso: View {
    let piso: Piso

    private var ocupacion: Double {
        piso.ocupacion.total > 0 ? Double(piso.ocupacion.alquiladas) / Double(piso.ocupacion.total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.s) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(piso.direccion)
                        .font(Tema.Fuente.subtitulo)
                        .fixedSize(horizontal: false, vertical: true)
                    Label(piso.ciudad.nombre, systemImage: "mappin.and.ellipse")
                        .font(Tema.Fuente.detalle)
                        .foregroundStyle(Tema.Color.textoSecundario)
                }
                Spacer(minLength: Tema.Espacio.xs)
                piso.metricas?.calificacion.insignia ?? Calificacion?.none.insignia
            }

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cash flow mensual").estiloEtiqueta()
                    if let m = piso.metricas {
                        Text(Formato.euros(m.cashFlowMensual))
                            .font(Tema.Fuente.cifra)
                            .foregroundStyle(Tono.signo(m.cashFlowMensual).color)
                    } else {
                        Text("Sin datos financieros")
                            .font(Tema.Fuente.detalle)
                            .foregroundStyle(Tema.Color.textoSecundario)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Rent. bruta").estiloEtiqueta()
                    Text(Formato.porcentaje(piso.metricas?.rentabilidadBrutaPct))
                        .font(Tema.Fuente.cifraPequena)
                }
            }

            VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
                ProgressView(value: ocupacion)
                    .tint(ocupacion >= 0.75 ? Tema.Color.positivo : (ocupacion >= 0.5 ? Tema.Color.aviso : Tema.Color.negativo))
                Text("\(piso.ocupacion.alquiladas) de \(piso.ocupacion.total) habitaciones alquiladas")
                    .font(Tema.Fuente.nota)
                    .foregroundStyle(Tema.Color.textoSecundario)
            }
        }
        .tarjeta()
        .accessibilityElement(children: .combine)
    }
}
