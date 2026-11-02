import SwiftUI

/// Lo cobrado del mes frente a lo esperado: la cifra que más importa al abrir la app.
struct HeroeInicio: View {
    let dashboard: Dashboard
    let generandoInforme: Bool
    let informe: () -> Void

    var body: some View {
        let d = dashboard
        let pendiente = max(d.esperadoMes - d.cobradoMes, 0)
        let progreso = d.esperadoMes > 0 ? (d.cobradoMes / d.esperadoMes).double : 0
        TarjetaHero(titulo: "Cobrado este mes", valor: Formato.euros(d.cobradoMes),
                    accesorio: (InicioViewModel.mostrarComparacion(cobrado: d.cobradoMes) ? d.tendenciaPct : nil).map { t in
                        AnyView(InsigniaEstado(texto: "\(Formato.porcentaje(abs(t))) vs. \(d.mesComparado).",
                                               tono: Tono.signo(t),
                                               icono: t >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .accessibilityLabel("\(t >= 0 ? "Sube" : "Baja") un \(Formato.porcentaje(abs(t))) frente a lo cobrado hasta el día \(d.diaComparado) del mes anterior"))
                    }) {
            VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                BarraProgreso(valor: progreso, tono: .positivo)
                Text("\(Formato.porcentaje(progreso * 100)) de \(Formato.euros(d.esperadoMes)) esperados")
                    .font(Tema.Fuente.nota)
                    .foregroundStyle(Tema.Color.textoSecundario)
            }
            ParDatos {
                DatoCompacto(titulo: "Pendiente de cobrar", valor: Formato.euros(pendiente), tono: pendiente > 0 ? .aviso : .positivo)
            } derecha: {
                DatoCompacto(titulo: "Cash flow previsto", valor: Formato.euros(d.cashFlowMensual), tono: Tono.signo(d.cashFlowMensual))
            }
            BotonSecundario(titulo: "Informe del mes", icono: "doc.richtext", cargando: generandoInforme, accion: informe)
        }
    }
}

/// Cuatro indicadores en rejilla (no perezosa, para que las dos tarjetas de cada fila midan lo mismo).
/// Cada uno abre su pantalla: ocupación por piso, habitaciones libres, contratos activos e incidencias abiertas.
struct IndicadoresInicio: View {
    let dashboard: Dashboard
    let zoom: Namespace.ID
    let abrir: (DestinoInicio) -> Void

    var body: some View {
        let d = dashboard
        let abiertas = d.incidenciasPendientes + d.incidenciasEnProceso
        Grid(horizontalSpacing: Tema.Espacio.s, verticalSpacing: Tema.Espacio.s) {
            GridRow {
                tocable("kpiOcupacion", .ocupacion, pista: "Abre la ocupación de cada piso") {
                    TarjetaKPI(titulo: "Ocupación", valor: Formato.porcentaje(d.ocupacion.porcentaje),
                               icono: "chart.pie", tono: d.ocupacion.tono,
                               detalle: "\(d.ocupacion.alquiladas) de \(d.ocupacion.habitaciones) habitaciones")
                }
                tocable("kpiLibres", .habitacionesLibres, pista: "Abre la lista de habitaciones libres") {
                    TarjetaKPI(titulo: "Habitaciones libres", valor: "\(d.ocupacion.disponibles)",
                               icono: "door.left.hand.open", tono: .primario,
                               detalle: "\(d.ocupacion.mantenimiento) en mantenimiento")
                }
            }
            GridRow {
                tocable("kpiContratos", .contratos(.activos), pista: "Abre los contratos activos") {
                    TarjetaKPI(titulo: "Contratos activos", valor: "\(d.contratosActivos)", icono: "doc.text",
                               tono: .primario, detalle: "\(d.inquilinos) inquilinos")
                }
                tocable("kpiIncidencias", .incidencias(.abiertas), pista: "Abre las incidencias abiertas y en curso") {
                    TarjetaKPI(titulo: "Incidencias abiertas", valor: "\(abiertas)",
                               icono: "wrench.and.screwdriver", tono: abiertas > 0 ? .aviso : .positivo,
                               detalle: "\(d.incidenciasEnProceso) en curso")
                }
            }
        }
    }

    private func tocable(_ id: String, _ destino: DestinoInicio, pista: String, @ViewBuilder tarjeta: () -> some View) -> some View {
        TarjetaTocable(pista: pista, accion: { abrir(destino) }, contenido: tarjeta)
            .matchedTransitionSource(id: destino, in: zoom)
            .accessibilityIdentifier(id)
    }
}

/// Alertas del panel. Cada una abre su lista ya filtrada ("5 contratos vencen…" → esos contratos).
struct AlertasInicio: View {
    let alertas: [Alerta]
    let zoom: Namespace.ID
    let abrir: (DestinoInicio) -> Void

    var body: some View {
        if !alertas.isEmpty {
            SeccionTarjeta(titulo: "Alertas") {
                ForEach(alertas, id: \.self) { a in
                    if let destino = ResumenesInicio.destino(de: a) {
                        TarjetaTocable(pista: "Abre la lista filtrada", mostrarChevron: false, accion: { abrir(destino) }) {
                            fila(a, chevron: true)
                        }
                        .matchedTransitionSource(id: destino, in: zoom)
                        .accessibilityIdentifier("alerta-\(a.tipo)")
                    } else {
                        fila(a, chevron: false)
                    }
                    if a != alertas.last { Divider().overlay(Tema.Color.borde) }
                }
            }
        }
    }

    private func fila(_ a: Alerta, chevron: Bool) -> some View {
        HStack(alignment: .center, spacing: Tema.Espacio.s) {
            IconoEtiqueta(icono: a.icono, tono: a.tonoVisual)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(a.titulo).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                    .fixedSize(horizontal: false, vertical: true)
                if !a.mensaje.isEmpty {
                    Text(a.mensaje).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                }
            }
            Spacer(minLength: Tema.Espacio.xs)
            if chevron { ChevronTocable() }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct VencimientosInicio: View {
    let contratos: [Contrato]

    var body: some View {
        SeccionTarjeta(titulo: "Próximos vencimientos") {
            if contratos.isEmpty {
                HStack(spacing: Tema.Espacio.s) {
                    IconoEtiqueta(icono: "checkmark.seal", tono: .positivo)
                    Text("Sin vencimientos en los próximos 30 días")
                        .font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                }
            }
            ForEach(contratos) { c in
                NavigationLink(value: DestinoInicio.contrato(c.id)) {
                    HStack(spacing: Tema.Espacio.s) {
                        AvatarIniciales(nombre: c.inquilino.nombre, tamano: Tema.Tamano.icono)
                        VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                            // El nombre nunca se corta: pasa a dos líneas si hace falta.
                            Text(c.inquilino.nombre).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Hab. \(c.habitacion.numero) · \(c.piso.direccion)")
                                .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario).lineLimit(2)
                        }
                        Spacer(minLength: Tema.Espacio.xs)
                        InsigniaEstado(texto: c.diasRestantes == 0 ? "Hoy" : "\(c.diasRestantes) d", tono: c.vencimiento.tono)
                            .accessibilityLabel(c.diasRestantes == 0 ? "Vence hoy" : "Vence en \(c.diasRestantes) días")
                        Image(systemName: "chevron.right").font(Tema.Fuente.nota.weight(.semibold))
                            .foregroundStyle(Tema.Color.textoSecundario)
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if c != contratos.last { Divider().overlay(Tema.Color.borde) }
            }
        }
    }
}

struct ActividadInicio: View {
    let actividades: [Actividad]

    var body: some View {
        SeccionTarjeta(titulo: "Actividad reciente") {
            NavigationLink(value: DestinoInicio.actividad) { Text("Ver todo") }
                .accessibilityLabel("Ver toda la actividad")
        } contenido: {
            if actividades.isEmpty {
                Text("Sin actividad registrada todavía.").foregroundStyle(Tema.Color.textoSecundario)
            }
            ForEach(actividades) { a in
                FilaActividad(actividad: a)
                if a != actividades.last { Divider().overlay(Tema.Color.borde) }
            }
        }
    }
}
