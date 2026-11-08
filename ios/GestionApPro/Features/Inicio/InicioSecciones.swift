import SwiftUI

/// Lo cobrado en un mes frente a lo esperado: la cifra que más importa al abrir la app.
/// Con las flechas (o deslizando) se ven meses anteriores, sin pasar de hoy; al tocarla se abre Cobros
/// en ese mes. Las cifras salen del mismo cálculo que Cobros (resumen del mes).
struct HeroeInicio: View {
    let dashboard: Dashboard
    let resumen: ResumenPagos?
    let mes: Mes
    let generandoInforme: Bool
    let cambiarMes: (Mes) -> Void
    let abrirCobros: () -> Void
    let informe: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private var esActual: Bool { mes == .actual }

    var body: some View {
        let d = dashboard
        // Mientras llega el resumen del mes actual, las cifras del panel (las mismas salvo matices).
        let cobrado = resumen?.cobrado ?? (esActual ? d.cobradoMes : 0)
        let esperado = resumen?.esperado ?? (esActual ? d.esperadoMes : 0)
        let pendiente = resumen?.pendiente ?? max(esperado - cobrado, 0)
        let progreso = esperado > 0 ? min((cobrado / esperado).double, 1) : 0
        TarjetaHero(titulo: esActual ? "Cobrado este mes" : String(localized: "Cobrado en \(Formato.mesEnFrase(mes.texto) ?? mes.nombre)"),
                    valor: Formato.euros(cobrado),
                    accesorio: (esActual && InicioViewModel.mostrarComparacion(cobrado: d.cobradoMes) ? d.tendenciaPct : nil).map { t in
                        let anterior = Formato.mes(Mes.actual.anterior.texto, corto: true) ?? d.mesComparado
                        return AnyView(InsigniaEstado(texto: "\(Formato.porcentaje(abs(t))) vs. \(anterior).",
                                                      tono: Tono.signo(t),
                                                      icono: t >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .accessibilityLabel("\(t >= 0 ? "Sube" : "Baja") un \(Formato.porcentaje(abs(t))) frente a lo cobrado hasta el día \(d.diaComparado) del mes anterior"))
                    }) {
            selectorMes
            VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                BarraProgreso(valor: progreso, tono: .positivo)
                Text("\(Formato.porcentaje(progreso * 100)) de \(Formato.euros(esperado)) esperados")
                    .font(Tema.Fuente.nota)
                    .foregroundStyle(Tema.Color.textoSecundario)
            }
            ParDatos {
                DatoCompacto(titulo: "Pendiente de cobrar", valor: Formato.euros(pendiente), tono: pendiente > 0 ? .aviso : .positivo)
            } derecha: {
                if esActual {
                    DatoCompacto(titulo: "Cash flow previsto", valor: Formato.euros(d.cashFlowMensual), tono: Tono.signo(d.cashFlowMensual))
                } else if let r = resumen {
                    DatoCompacto(titulo: "Pagos registrados", valor: "\(r.numeroPagos)")
                }
            }
            BotonSecundario(titulo: "Informe del mes", icono: "doc.richtext", cargando: generandoInforme, accion: informe)
        }
        .overlay(alignment: .topTrailing) {
            if !esActual || !InicioViewModel.mostrarComparacion(cobrado: d.cobradoMes) || d.tendenciaPct == nil {
                ChevronTocable().padding(Tema.Espacio.l)
            }
        }
        .contentShape(.rect)
        // Tocar la tarjeta (fuera de sus botones) abre Cobros en ese mes.
        .onTapGesture {
            Haptica.ligera()
            abrirCobros()
        }
        // Deslizar a la izquierda: mes siguiente; a la derecha: anterior. No bloquea el desplazamiento vertical.
        .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) * 1.5, abs(v.translation.width) > 60 else { return }
            ir(v.translation.width < 0 ? mes.siguiente : mes.anterior)
        })
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Ver en Cobros"), abrirCobros)
        .accessibilityIdentifier("heroeInicio")
    }

    private var selectorMes: some View {
        HStack(spacing: Tema.Espacio.s) {
            Button { ir(mes.anterior) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Mes anterior")
                .accessibilityIdentifier("heroeMesAnterior")
            Text(mes.nombre)
                .font(Tema.Fuente.detalle.weight(.semibold))
                .foregroundStyle(Tema.Color.texto)
                .contentTransition(reducirMovimiento ? .identity : .numericText())
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Mes: \(mes.nombre)")
                .accessibilityHint("Desliza arriba o abajo para cambiar de mes")
                .accessibilityAdjustableAction { direccion in
                    switch direccion {
                    case .increment: ir(mes.siguiente)
                    case .decrement: ir(mes.anterior)
                    @unknown default: break
                    }
                }
            Button { ir(mes.siguiente) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Mes siguiente")
                .accessibilityIdentifier("heroeMesSiguiente")
                .disabled(esActual)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(Tema.Color.texto)
    }

    private func ir(_ nuevo: Mes) {
        guard nuevo <= .actual, nuevo != mes else { return }
        Haptica.ligera()
        if reducirMovimiento { cambiarMes(nuevo) } else { withAnimation(Tema.Movimiento.suave) { cambiarMes(nuevo) } }
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
                tocable("kpiOcupacion", .ocupacion, pista: "Abre la ocupación de cada inmueble") {
                    TarjetaKPI(titulo: "Ocupación", valor: Formato.porcentaje(d.ocupacion.porcentaje),
                               icono: "chart.pie", tono: d.ocupacion.tono,
                               detalle: String(localized: "\(d.ocupacion.alquiladas) de \(d.ocupacion.habitaciones) \(d.ocupacion.plural)"))
                }
                tocable("kpiLibres", .habitacionesLibres, pista: d.ocupacion.conOtrosTipos == true
                        ? String(localized: "Abre la lista de unidades libres") : String(localized: "Abre la lista de habitaciones libres")) {
                    TarjetaKPI(titulo: d.ocupacion.conOtrosTipos == true ? String(localized: "Unidades libres") : String(localized: "Habitaciones libres"), valor: "\(d.ocupacion.disponibles)",
                               icono: "door.left.hand.open", tono: .primario,
                               detalle: String(localized: "\(d.ocupacion.mantenimiento) en mantenimiento"))
                }
            }
            GridRow {
                tocable("kpiContratos", .contratos(.activos), pista: "Abre los contratos activos") {
                    TarjetaKPI(titulo: "Contratos activos", valor: "\(d.contratosActivos)", icono: "doc.text",
                               tono: .primario, detalle: String(localized: "\(d.inquilinos) inquilinos"))
                }
                tocable("kpiIncidencias", .incidencias(.abiertas), pista: "Abre las incidencias abiertas y en curso") {
                    TarjetaKPI(titulo: "Incidencias abiertas", valor: "\(abiertas)",
                               icono: "wrench.and.screwdriver", tono: abiertas > 0 ? .aviso : .positivo,
                               detalle: String(localized: "\(d.incidenciasEnProceso) en curso"))
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
                            Text("\(c.habitacion.etiqueta) · \(c.piso.direccion)")
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
                .accessibilityIdentifier("filaVencimiento")
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
                .accessibilityIdentifier("verActividad")
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
