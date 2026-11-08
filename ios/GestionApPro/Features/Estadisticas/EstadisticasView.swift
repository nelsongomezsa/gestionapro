import Charts
import SwiftUI

/// Estadísticas con filtros: cartera, piso o habitación; mes, trimestre, año o personalizado.
/// Ingresos frente a gastos, ranking de pisos, ocupación histórica, días medios vacía, morosidad,
/// rotación y comparación con el año anterior, con exportación a PDF. Debajo, la situación de hoy.
struct EstadisticasView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = EstadisticasViewModel()
    @State private var documento: DocumentoPDF?

    private struct Clave: Equatable {
        let periodo: PeriodoEstadisticas
        let ambito: AmbitoEstadisticas
    }

    var body: some View {
        @Bindable var vm = vm
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                FiltrosEstadisticas(vm: vm)
                switch vm.analisis {
                case .cargando:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                case let .error(mensaje):
                    EstadoVacio(icono: "exclamationmark.triangle", titulo: "No se pudieron cargar", mensaje: mensaje,
                                accionTitulo: "Reintentar") { Task { await vm.cargar(con: sesion.api) } }
                case let .cargado(a):
                    ContenidoAnalisis(analisis: a, periodo: vm.periodo, unidades: vm.unidades, soloHabitaciones: vm.soloHabitaciones)
                        .opacity(vm.cargando ? 0.5 : 1)
                }
                if let s = vm.situacion { SituacionActual(estadisticas: s) }
            }
            .padding(.horizontal, Tema.Espacio.m)
            .padding(.bottom, Tema.Espacio.l)
        }
        .background(Tema.Color.fondo)
        .navigationTitle("Estadísticas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Exportar PDF", systemImage: "doc.richtext") {
                    if let a = vm.analisis.valor { documento = vm.pdf(a) }
                }
                .disabled(vm.analisis.valor == nil)
                .accessibilityIdentifier("exportarEstadisticas")
            }
        }
        .refreshable {
            await vm.cargarListas(con: sesion.api)
            await vm.cargar(con: sesion.api)
        }
        .task { await vm.cargarListas(con: sesion.api) }
        .task(id: Clave(periodo: vm.periodo, ambito: vm.ambito)) { await vm.cargar(con: sesion.api) }
        .visorPDF($documento)
        .alertaError($vm.error)
    }
}

/// Ámbito (cartera, piso o habitación) y periodo (tipo y cuál).
private struct FiltrosEstadisticas: View {
    @Bindable var vm: EstadisticasViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.s) {
            Menu {
                Button { vm.ambito = .cartera } label: { etiqueta(String(localized: "Toda la cartera"), elegido: vm.ambito == .cartera) }
                if vm.tiposPresentes.count > 1 {
                    Section("Por tipo") {
                        ForEach(vm.tiposPresentes) { t in
                            Button { vm.ambito = .tipo(t) } label: { etiqueta(t.nombre, elegido: vm.ambito == .tipo(t)) }
                        }
                    }
                }
                Section("Inmuebles") {
                    ForEach(vm.pisos) { p in
                        Button { vm.ambito = .piso(p.breve) } label: { etiqueta(p.direccion, elegido: vm.ambito == .piso(p.breve)) }
                    }
                }
                Section(Unidades.pluralTitulo(conOtrosTipos: vm.pisos.contains { $0.tipoInmueble != .vivienda })) {
                    ForEach(vm.pisos) { p in
                        Menu(p.direccion) {
                            ForEach(vm.habitaciones.filter { $0.piso.id == p.id }.sorted { $0.numero < $1.numero }) { h in
                                Button { vm.ambito = .habitacion(h) } label: {
                                    etiqueta(String(localized: "\(h.titulo)"), elegido: vm.ambito == .habitacion(h))
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Tema.Espacio.xs) {
                    Image(systemName: icono).foregroundStyle(Tema.Color.primario)
                    Text(vm.ambito.titulo).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                        .lineLimit(2).multilineTextAlignment(.leading)
                    Spacer(minLength: Tema.Espacio.xs)
                    Image(systemName: "chevron.up.chevron.down").font(Tema.Fuente.nota.weight(.semibold))
                        .foregroundStyle(Tema.Color.textoSecundario)
                }
                .frame(minHeight: Tema.Tamano.botonRedondo)
                .contentShape(.rect)
            }
            .accessibilityLabel("Analizar")
            .accessibilityValue(vm.ambito.titulo)
            .accessibilityIdentifier("ambitoEstadisticas")

            Picker("Periodo", selection: Binding(get: { vm.periodo.tipo }, set: { vm.cambiarTipo($0) })) {
                ForEach(PeriodoEstadisticas.Tipo.allCases) { Text($0.nombre).tag($0) }
            }
            .pickerStyle(.segmented)
            .sensoryFeedback(.selection, trigger: vm.periodo.tipo)

            if vm.periodo.tipo == .personalizado {
                DatePicker("Desde", selection: Binding(get: { vm.periodo.desde }, set: { nuevo in
                    vm.periodo.desde = nuevo
                    if vm.periodo.hasta < nuevo { vm.periodo.hasta = nuevo }
                }), in: ...Date.now, displayedComponents: .date)
                DatePicker("Hasta", selection: $vm.periodo.hasta, in: vm.periodo.desde...Date.now, displayedComponents: .date)
            } else {
                HStack {
                    Button { vm.periodo = vm.periodo.desplazado(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Periodo anterior")
                    Spacer()
                    Text(vm.periodo.titulo).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                        .contentTransition(.numericText())
                    Spacer()
                    Button { vm.periodo = vm.periodo.desplazado(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Periodo siguiente")
                        .disabled(!vm.periodo.puedeAvanzar)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(Tema.Color.primario)
            }
        }
        .environment(\.locale, Formato.localeFechas)
        .tarjeta()
    }

    private var icono: String {
        switch vm.ambito {
        case .cartera: "square.grid.2x2"
        case let .tipo(t): t.icono
        case .piso: "building.2"
        case let .habitacion(h): h.unidad.icono
        }
    }

    @ViewBuilder
    private func etiqueta(_ texto: String, elegido: Bool) -> some View {
        if elegido { Label(texto, systemImage: "checkmark") } else { Text(texto) }
    }
}

/// Todo lo que depende del filtro.
private struct ContenidoAnalisis: View {
    let analisis: Analisis
    let periodo: PeriodoEstadisticas
    /// "habitaciones", "plazas", "trasteros" o "unidades".
    var unidades = TipoUnidad.habitacion.pluralMinusculas
    var soloHabitaciones = true

    var body: some View {
        let a = analisis, t = a.actual
        VStack(alignment: .leading, spacing: Tema.Espacio.l) {
            TarjetaHero(titulo: "Resultado neto", valor: Formato.euros(t.neto),
                        accesorio: variacionPct(t.neto, a.anterior.neto).map { v in
                            AnyView(InsigniaEstado(texto: String(localized: "\(Formato.porcentaje(abs(v))) vs. año anterior"),
                                                   tono: Tono.signo(v), icono: v >= 0 ? "arrow.up.right" : "arrow.down.right"))
                        },
                        tonoValor: t.neto < 0 ? .negativo : nil) {
                ParDatos {
                    DatoCompacto(titulo: "Ingresos", valor: Formato.euros(t.ingresos), tono: .positivo)
                } derecha: {
                    DatoCompacto(titulo: "Gastos", valor: Formato.euros(t.gastos), tono: t.gastos > 0 ? .negativo : nil)
                }
            }

            SeccionTarjeta(titulo: "Comparación con el año anterior") {
                FilaComparacion(titulo: "Ingresos", actual: Formato.euros(t.ingresos), anterior: Formato.euros(a.anterior.ingresos),
                                variacion: variacionPct(t.ingresos, a.anterior.ingresos), mayorEsMejor: true)
                Divider().overlay(Tema.Color.borde)
                FilaComparacion(titulo: "Gastos", actual: Formato.euros(t.gastos), anterior: Formato.euros(a.anterior.gastos),
                                variacion: variacionPct(t.gastos, a.anterior.gastos), mayorEsMejor: false)
                Divider().overlay(Tema.Color.borde)
                FilaComparacion(titulo: "Resultado neto", actual: Formato.euros(t.neto), anterior: Formato.euros(a.anterior.neto),
                                variacion: variacionPct(t.neto, a.anterior.neto), mayorEsMejor: true)
                Divider().overlay(Tema.Color.borde)
                FilaComparacion(titulo: "Ocupación", actual: Formato.porcentaje(t.ocupacionPct),
                                anterior: Formato.porcentaje(a.anterior.ocupacionPct),
                                puntos: t.ocupacionPct - a.anterior.ocupacionPct, mayorEsMejor: true)
                Divider().overlay(Tema.Color.borde)
                FilaComparacion(titulo: "Impagado", actual: Formato.euros(t.impagado), anterior: Formato.euros(a.anterior.impagado),
                                variacion: variacionPct(t.impagado, a.anterior.impagado), mayorEsMejor: false)
            }

            SeccionTarjeta(titulo: "Ingresos y gastos por mes") {
                GraficoCobrosGastos(meses: a.meses.map {
                    CobrosGastosMes(mes: $0.mes, etiqueta: $0.etiqueta, cobros: $0.ingresos, gastos: $0.gastos)
                })
                .frame(height: 220)
            }

            if a.pisos.count > 1 {
                SeccionTarjeta(titulo: "Ingresos frente a gastos por inmueble") { GraficoPisos(pisos: a.pisos) }
                SeccionTarjeta(titulo: "Ranking de inmuebles") {
                    ForEach(Array(a.pisos.enumerated()), id: \.element.id) { i, p in
                        FilaRanking(puesto: i + 1, piso: p)
                        if i < a.pisos.count - 1 { Divider().overlay(Tema.Color.borde) }
                    }
                }
            }

            SeccionTarjeta(titulo: "Ocupación histórica") { GraficoOcupacion(meses: a.meses.filter { $0.ocupacionPct != nil }) }

            Grid(horizontalSpacing: Tema.Espacio.s, verticalSpacing: Tema.Espacio.s) {
                GridRow {
                    TarjetaKPI(titulo: "Ocupación", valor: Formato.porcentaje(t.ocupacionPct), icono: "chart.pie",
                               tono: Tono.ocupacion(t.ocupacionPct), detalle: "\(t.habitaciones) \(unidades)")
                    TarjetaKPI(titulo: soloHabitaciones ? String(localized: "Días medios vacía") : String(localized: "Días medios sin alquilar"),
                               valor: Formato.numero(t.diasMediosVacia), icono: "calendar.badge.minus",
                               tono: .primario, detalle: soloHabitaciones ? String(localized: "Por habitación") : String(localized: "Por unidad"))
                }
                GridRow {
                    TarjetaKPI(titulo: "Rotación", valor: Formato.porcentaje(t.rotacionPct), icono: "arrow.triangle.2.circlepath",
                               tono: .primario,
                               detalle: String(localized: "\(t.contratosIniciados) altas · \(t.contratosFinalizados) bajas"))
                    TarjetaKPI(titulo: "Duración media", valor: t.duracionMediaMeses.map { String(localized: "\(Formato.numero($0)) meses") } ?? "—",
                               icono: "hourglass", tono: .primario, detalle: "Contratos finalizados")
                }
            }

            SeccionTarjeta(titulo: "Morosidad por inquilino") {
                if a.morosidad.isEmpty {
                    Text("Sin meses vencidos en este periodo.").font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                }
                ForEach(a.morosidad) { m in
                    FilaMorosidad(morosidad: m)
                    if m != a.morosidad.last { Divider().overlay(Tema.Color.borde) }
                }
            }
        }
    }
}

/// "Ingresos   1.200 € · antes 1.000 €   ↑ 20 %"
private struct FilaComparacion: View {
    let titulo: String
    let actual: String
    let anterior: String
    var variacion: Double? = nil
    /// Diferencia en puntos (ocupación), en lugar de variación en %.
    var puntos: Double? = nil
    let mayorEsMejor: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.s) {
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(LocalizedStringKey(titulo)).font(Tema.Fuente.cuerpo)
                Text("Año anterior: \(anterior)").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
            Spacer(minLength: Tema.Espacio.xs)
            VStack(alignment: .trailing, spacing: Tema.Espacio.linea) {
                Text(actual).font(Tema.Fuente.cifraPequena)
                if let cambio {
                    Label(cambio.texto, systemImage: cambio.valor >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(Tema.Fuente.nota.weight(.semibold))
                        .foregroundStyle(cambio.tono.color)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var cambio: (valor: Double, texto: String, tono: Tono)? {
        if let puntos {
            guard abs(puntos) >= 0.01 else { return nil }
            let t = String(localized: "\(Formato.numero(abs(puntos))) puntos")
            return (puntos, t, puntos == 0 ? .neutro : ((puntos > 0) == mayorEsMejor ? .positivo : .negativo))
        }
        guard let variacion, abs(variacion) >= 0.01 else { return nil }
        return (variacion, Formato.porcentaje(abs(variacion)),
                variacion == 0 ? .neutro : ((variacion > 0) == mayorEsMejor ? .positivo : .negativo))
    }
}

private struct FilaRanking: View {
    let puesto: Int
    let piso: Analisis.PisoAnalisis

    var body: some View {
        HStack(spacing: Tema.Espacio.s) {
            Text("\(puesto)")
                .font(Tema.Fuente.cifraPequena)
                .frame(width: Tema.Tamano.icono, height: Tema.Tamano.icono)
                .background((puesto == 1 ? Tema.Color.positivo : Tema.Color.primario).opacity(0.14), in: .circle)
                .foregroundStyle(puesto == 1 ? Tema.Color.positivo : Tema.Color.primario)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(piso.piso.direccion).font(Tema.Fuente.subtitulo).fixedSize(horizontal: false, vertical: true)
                Text("Ocupación \(Formato.porcentaje(piso.ocupacionPct)) · \(Formato.numero(piso.diasMediosVacia)) días vacía")
                    .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
            Spacer(minLength: Tema.Espacio.xs)
            Text(Formato.euros(piso.neto)).font(Tema.Fuente.cifraPequena).foregroundStyle(Tono.signo(piso.neto).color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Puesto \(puesto): \(piso.piso.direccion)")
    }
}

private struct FilaMorosidad: View {
    let morosidad: Analisis.Morosidad

    var body: some View {
        let m = morosidad
        HStack(alignment: .top, spacing: Tema.Espacio.s) {
            AvatarIniciales(nombre: m.nombre, tamano: Tema.Tamano.icono)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(m.nombre).font(Tema.Fuente.subtitulo)
                Text("\(m.mesesImpagados) de \(m.mesesDebidos) meses sin pagar · \(m.pagosFueraDePlazo) fuera de plazo")
                    .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
            Spacer(minLength: Tema.Espacio.xs)
            VStack(alignment: .trailing, spacing: Tema.Espacio.linea) {
                Text(Formato.euros(m.importeImpagado)).font(Tema.Fuente.cifraPequena)
                    .foregroundStyle(m.importeImpagado > 0 ? Tema.Color.negativo : Tema.Color.texto)
                InsigniaEstado(texto: String(localized: "\(Formato.porcentaje(m.puntualidadPct)) a tiempo"),
                               tono: m.puntualidadPct >= 90 ? .positivo : (m.puntualidadPct >= 70 ? .aviso : .negativo))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Barras horizontales de ingresos y gastos por piso.
private struct GraficoPisos: View {
    let pisos: [Analisis.PisoAnalisis]

    var body: some View {
        Chart {
            ForEach(pisos) { p in
                BarMark(x: .value("Importe", p.ingresos.double), y: .value("Inmueble", p.piso.direccion))
                    .foregroundStyle(by: .value("Tipo", "Ingresos"))
                    .position(by: .value("Tipo", "Ingresos"))
                    .accessibilityLabel("\(p.piso.direccion), ingresos")
                    .accessibilityValue(Formato.euros(p.ingresos))
                BarMark(x: .value("Importe", p.gastos.double), y: .value("Inmueble", p.piso.direccion))
                    .foregroundStyle(by: .value("Tipo", "Gastos"))
                    .position(by: .value("Tipo", "Gastos"))
                    .accessibilityLabel("\(p.piso.direccion), gastos")
                    .accessibilityValue(Formato.euros(p.gastos))
            }
        }
        .chartForegroundStyleScale(["Ingresos": Tema.Color.positivo, "Gastos": Tema.Color.negativo])
        .chartLegend(position: .top, alignment: .leading)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { valor in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(Tema.Color.borde)
                AxisValueLabel {
                    if let v = valor.as(Double.self) {
                        Text(Formato.eurosRedondo(v)).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { _ in AxisValueLabel().font(Tema.Fuente.nota).foregroundStyle(Tema.Color.texto) }
        }
        .frame(height: CGFloat(pisos.count) * 52 + 40)
        .accessibilityLabel("Ingresos frente a gastos por inmueble")
    }
}

/// Ocupación de cada mes, con la referencia del 75 % (por encima, ocupación saludable).
private struct GraficoOcupacion: View {
    let meses: [Analisis.MesAnalisis]
    @State private var dibujado = false
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        Chart {
            ForEach(meses) { m in
                AreaMark(x: .value("Mes", m.etiqueta), y: .value("Ocupación", dibujado ? m.ocupacionPct ?? 0 : 0))
                    .foregroundStyle(Tema.Color.primario.opacity(0.15))
                    .accessibilityHidden(true)
                LineMark(x: .value("Mes", m.etiqueta), y: .value("Ocupación", dibujado ? m.ocupacionPct ?? 0 : 0))
                    .foregroundStyle(Tema.Color.primario)
                    .symbol(.circle)
                    .accessibilityLabel(m.etiqueta.capitalized(with: Formato.localeFechas))
                    .accessibilityValue(Formato.porcentaje(m.ocupacionPct))
            }
            RuleMark(y: .value("Referencia", 75))
                .foregroundStyle(Tema.Color.positivo)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text("75 %").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.positivo)
                }
                .accessibilityLabel("Referencia de ocupación saludable")
                .accessibilityValue("75 %")
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { valor in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(Tema.Color.borde)
                AxisValueLabel {
                    if let v = valor.as(Double.self) {
                        Text(Formato.porcentaje(v)).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { valor in
                AxisValueLabel {
                    if let e = valor.as(String.self), let i = meses.firstIndex(where: { $0.etiqueta == e }),
                       meses.count <= 6 || (meses.count - 1 - i) % max(meses.count / 6, 1) == 0 {
                        Text(e).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    }
                }
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Ocupación por mes")
        .onAppear {
            if reducirMovimiento { dibujado = true } else { withAnimation(Tema.Movimiento.entrada.delay(0.15)) { dibujado = true } }
        }
    }
}

/// Habitaciones por estado hoy e incidencias de los últimos 6 meses (no dependen del filtro).
private struct SituacionActual: View {
    let estadisticas: Estadisticas

    var body: some View {
        let e = estadisticas
        VStack(alignment: .leading, spacing: Tema.Espacio.l) {
            Text("Situación actual").font(Tema.Fuente.titulo).foregroundStyle(Tema.Color.texto)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Tema.Espacio.s)
            SeccionTarjeta(titulo: e.ocupacion.conOtrosTipos == true ? String(localized: "Unidades por estado") : String(localized: "Habitaciones por estado")) {
                AnilloHabitaciones(ocupacion: e.ocupacion)
            }
            SeccionTarjeta(titulo: "Incidencias comunicadas · 6 meses") {
                Chart(e.incidencias6Meses, id: \.mes) { m in
                    BarMark(x: .value("Mes", m.etiqueta), y: .value("Incidencias", m.cantidad), width: .ratio(0.55))
                        .foregroundStyle(Tema.Color.aviso)
                        .clipShape(.rect(cornerRadius: Tema.Radio.pequeno / 2))
                        .annotation(position: .top) {
                            if m.cantidad > 0 {
                                Text("\(m.cantidad)").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                            }
                        }
                        .accessibilityLabel(m.etiqueta.capitalized(with: Formato.localeFechas))
                        .accessibilityValue("\(m.cantidad) incidencias")
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    }
                }
                .frame(height: 160)
                .accessibilityLabel("Incidencias por mes")
            }
        }
    }
}

/// Anillo con las habitaciones alquiladas, disponibles y en mantenimiento, y su leyenda.
struct AnilloHabitaciones: View {
    let ocupacion: Ocupacion

    private var porciones: [(nombre: String, cantidad: Int, tono: Tono)] {
        [("Alquiladas", ocupacion.alquiladas, .positivo),
         ("Disponibles", ocupacion.disponibles, .primario),
         ("En mantenimiento", ocupacion.mantenimiento, .aviso)]
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tema.Espacio.l) { anillo; leyenda }
            VStack(spacing: Tema.Espacio.m) { anillo; leyenda }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Unidades.pluralTitulo(conOtrosTipos: ocupacion.conOtrosTipos ?? false)): \(Formato.porcentaje(ocupacion.porcentaje)) de ocupación")
        .accessibilityValue(porciones.map { "\($0.cantidad) \($0.nombre.lowercased())" }.joined(separator: ", "))
    }

    private var anillo: some View {
        Chart(porciones, id: \.nombre) { p in
            SectorMark(angle: .value("Habitaciones", p.cantidad), innerRadius: .ratio(0.65), angularInset: 1.5)
                .foregroundStyle(p.tono.color)
                .cornerRadius(Tema.Radio.pequeno / 2)
        }
        .frame(width: Tema.Tamano.anillo, height: Tema.Tamano.anillo)
        .overlay {
            VStack(spacing: 0) {
                Text(Formato.porcentaje(ocupacion.porcentaje)).font(Tema.Fuente.cifraPequena).foregroundStyle(Tema.Color.texto)
                Text("ocupación").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
        }
    }

    private var leyenda: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.s) {
            ForEach(porciones, id: \.nombre) { p in
                HStack(spacing: Tema.Espacio.xs) {
                    Circle().fill(p.tono.color).frame(width: Tema.Tamano.punto * 1.5, height: Tema.Tamano.punto * 1.5)
                    Text(p.nombre).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.texto)
                    Spacer(minLength: Tema.Espacio.xs)
                    Text("\(p.cantidad)").font(Tema.Fuente.cifraPequena).foregroundStyle(Tema.Color.texto)
                }
            }
            Text("de \(ocupacion.habitaciones) \(ocupacion.plural)")
                .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
        }
    }
}
