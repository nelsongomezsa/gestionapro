import SwiftUI

/// Compara entre sí las unidades sueltas (plazas y trasteros comprados por separado).
/// Usa las métricas previstas de cada inmueble, así que no depende del periodo elegido arriba.
struct RankingSueltasView: View {
    let pisos: [Piso]

    @State private var criterio: RankingSueltas.Criterio = .rentabilidad
    @State private var grupo: GrupoSueltas?

    private var grupos: [GrupoSueltas] {
        GrupoSueltas.allCases.filter { g in pisos.contains { $0.grupoSueltas == g } }
    }

    private var visibles: [Piso] {
        RankingSueltas.ordenar(pisos.filter { grupo == nil || $0.grupoSueltas == grupo }, por: criterio)
    }

    var body: some View {
        SeccionTarjeta(titulo: "Unidades sueltas") {
            Picker("Ordenar por", selection: $criterio.animation(Tema.Movimiento.suave)) {
                ForEach(RankingSueltas.Criterio.allCases) { Text($0.nombre).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("criterioRankingSueltas")

            if grupos.count > 1 {
                Picker("Tipo de unidad", selection: $grupo.animation(Tema.Movimiento.suave)) {
                    Text("Todas").tag(GrupoSueltas?.none)
                    ForEach(grupos) { Text($0.nombre).tag(GrupoSueltas?.some($0)) }
                }
                .pickerStyle(.segmented)
            }

            ForEach(Array(visibles.enumerated()), id: \.element.id) { i, p in
                fila(posicion: i + 1, piso: p)
                if i < visibles.count - 1 { Divider().overlay(Tema.Color.borde) }
            }

            let totales = TotalesSueltas(visibles)
            Divider().overlay(Tema.Color.borde)
            ParDatos {
                DatoCompacto(titulo: "Cash flow total", valor: Formato.euros(totales.cashFlowMensual),
                             tono: Tono.signo(totales.cashFlowMensual))
            } derecha: {
                DatoCompacto(titulo: "Rentabilidad total", valor: Formato.porcentaje(totales.rentabilidadBrutaPct))
            }
        }
        .accessibilityIdentifier("rankingSueltas")
    }

    private func fila(posicion: Int, piso: Piso) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.s) {
            Text("\(posicion)")
                .font(Tema.Fuente.detalle.weight(.semibold))
                .foregroundStyle(Tema.Color.textoSecundario)
                .monospacedDigit()
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(piso.direccion)
                    .font(Tema.Fuente.detalle)
                    .foregroundStyle(Tema.Color.texto)
                    .fixedSize(horizontal: false, vertical: true)
                Text(piso.ciudad.nombre)
                    .font(Tema.Fuente.nota)
                    .foregroundStyle(Tema.Color.textoSecundario)
            }
            Spacer(minLength: Tema.Espacio.xs)
            VStack(alignment: .trailing, spacing: Tema.Espacio.linea) {
                Text(Formato.porcentaje(piso.metricas?.rentabilidadBrutaPct))
                    .font(criterio == .rentabilidad ? Tema.Fuente.detalle.weight(.semibold) : Tema.Fuente.nota)
                    .foregroundStyle(criterio == .rentabilidad ? Tema.Color.texto : Tema.Color.textoSecundario)
                Text(Formato.euros(piso.metricas?.cashFlowMensual))
                    .font(criterio == .cashFlow ? Tema.Fuente.detalle.weight(.semibold) : Tema.Fuente.nota)
                    .foregroundStyle(Tono.signo(piso.metricas?.cashFlowMensual ?? 0).color)
            }
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Acceso desde Estadísticas: la lista va en su propia hoja para no alargar el análisis del periodo.
struct AccesoRankingSueltas: View {
    let cuantas: Int

    var body: some View {
        HStack(spacing: Tema.Espacio.s) {
            IconoEtiqueta(icono: "list.number", tono: .primario)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text("Comparar unidades sueltas").font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                Text("\(cuantas) plazas y trasteros, por rentabilidad y cash flow")
                    .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: Tema.Espacio.xs)
            ChevronTocable()
        }
        .tarjeta()
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
