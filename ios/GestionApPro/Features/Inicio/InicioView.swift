import Charts
import SwiftUI

/// Destinos que se abren desde Inicio (incluidos los de las notificaciones).
enum DestinoInicio: Hashable {
    case notificaciones
    case actividad
    case buscar
    case piso(Int)
    case inquilino(Int)
    case contrato(Int)
    case habitacion(Int)
    case incidencia(Int)
    case mensajes(Int)
}

/// Inicio (Dashboard del escritorio): lo cobrado del mes como cifra principal, indicadores,
/// ingresos de 6 meses, alertas, vencimientos, actividad, informe mensual en PDF,
/// búsqueda global y campana de notificaciones.
struct InicioView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<Dashboard> = .cargando
    /// Ruta explícita: las notificaciones abren su pantalla añadiéndola aquí.
    @State private var ruta: [DestinoInicio] = []
    @State private var noLeidas = 0
    @State private var documento: DocumentoPDF?
    @State private var generandoInforme = false
    @State private var error: String?

    /// Cuántas actividades se ven en Inicio; el resto, en "Ver todo".
    private let actividadesVisibles = 4

    var body: some View {
        NavigationStack(path: $ruta) {
            VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { d in
                ScrollView {
                    VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                        heroe(d)

                        // Grid (no perezoso) para que las dos tarjetas de cada fila midan lo mismo.
                        Grid(horizontalSpacing: Tema.Espacio.s, verticalSpacing: Tema.Espacio.s) {
                            GridRow {
                                TarjetaKPI(titulo: "Ocupación", valor: Formato.porcentaje(d.ocupacion.porcentaje),
                                           icono: "chart.pie", tono: d.ocupacion.tono,
                                           detalle: "\(d.ocupacion.alquiladas) de \(d.ocupacion.habitaciones) habitaciones")
                                TarjetaKPI(titulo: "Habitaciones libres", valor: "\(d.ocupacion.disponibles)",
                                           icono: "door.left.hand.open", tono: .primario,
                                           detalle: "\(d.ocupacion.mantenimiento) en mantenimiento")
                            }
                            GridRow {
                                TarjetaKPI(titulo: "Contratos activos", valor: "\(d.contratosActivos)", icono: "doc.text",
                                           tono: .primario, detalle: "\(d.inquilinos) inquilinos")
                                TarjetaKPI(titulo: "Incidencias abiertas",
                                           valor: "\(d.incidenciasPendientes + d.incidenciasEnProceso)",
                                           icono: "wrench.and.screwdriver",
                                           tono: d.incidenciasPendientes + d.incidenciasEnProceso > 0 ? .aviso : .positivo,
                                           detalle: "\(d.incidenciasEnProceso) en curso")
                            }
                        }

                        SeccionTarjeta(titulo: "Ingresos cobrados") {
                            GraficoIngresos(meses: d.ingresosUltimos6Meses).frame(height: 220)
                        }

                        if !alertas(d).isEmpty {
                            SeccionTarjeta(titulo: "Alertas") {
                                ForEach(alertas(d), id: \.self) { a in
                                    HStack(alignment: .top, spacing: Tema.Espacio.s) {
                                        IconoEtiqueta(icono: a.icono, tono: a.tonoVisual)
                                        VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                                            Text(a.titulo).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                                            if !a.mensaje.isEmpty {
                                                Text(a.mensaje).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                                            }
                                        }
                                    }
                                    .accessibilityElement(children: .combine)
                                    if a != alertas(d).last { Divider().overlay(Tema.Color.borde) }
                                }
                            }
                        }

                        SeccionTarjeta(titulo: "Próximos vencimientos") {
                            if d.proximosVencimientos.isEmpty {
                                HStack(spacing: Tema.Espacio.s) {
                                    IconoEtiqueta(icono: "checkmark.seal", tono: .positivo)
                                    Text("Sin vencimientos en los próximos 30 días")
                                        .font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                                }
                            }
                            ForEach(d.proximosVencimientos) { c in
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
                                if c != d.proximosVencimientos.last { Divider().overlay(Tema.Color.borde) }
                            }
                        }

                        SeccionTarjeta(titulo: "Actividad reciente") {
                            NavigationLink(value: DestinoInicio.actividad) { Text("Ver todo") }
                                .accessibilityLabel("Ver toda la actividad")
                        } contenido: {
                            if d.actividadReciente.isEmpty {
                                Text("Sin actividad registrada todavía.").foregroundStyle(Tema.Color.textoSecundario)
                            }
                            let visibles = Array(d.actividadReciente.prefix(actividadesVisibles))
                            ForEach(visibles) { a in
                                FilaActividad(actividad: a)
                                if a != visibles.last { Divider().overlay(Tema.Color.borde) }
                            }
                        }
                    }
                    .padding(.horizontal, Tema.Espacio.m)
                    .padding(.bottom, Tema.Espacio.l)
                }
                .background(Tema.Color.fondo)
            }
            .background(Tema.Color.fondo)
            .navigationTitle(saludo)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: DestinoInicio.buscar) {
                        Label("Buscar", systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("botonBuscar")
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: DestinoInicio.notificaciones) {
                        Image(systemName: noLeidas > 0 ? "bell.badge" : "bell")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Tema.Color.negativo, Tema.Color.texto)
                    }
                    .accessibilityLabel(noLeidas > 0 ? "Notificaciones, \(noLeidas) sin leer" : "Notificaciones")
                    .accessibilityIdentifier("campana")
                }
            }
            .navigationDestination(for: DestinoInicio.self) { destino in
                switch destino {
                case .notificaciones:
                    NotificacionesView(abrir: { ruta.append($0) }, alCambiar: { await contarNoLeidas() })
                case .actividad: ActividadView()
                case .buscar: BuscarView()
                case let .piso(id): PisoDestinoView(id: id)
                case let .inquilino(id): InquilinoFichaView(id: id)
                case let .contrato(id): ContratoDetalleView(id: id)
                case let .mensajes(id): ChatView(hilo: .contrato(id))
                case let .habitacion(id): HabitacionDestinoView(id: id)
                case let .incidencia(id): IncidenciaDestinoView(id: id)
                }
            }
            .refreshable { await cargar() }
            .task { await cargar() }
            .visorPDF($documento)
            .alertaError($error)
        }
    }

    /// Lo cobrado del mes frente a lo esperado: la cifra que más importa al abrir la app.
    private func heroe(_ d: Dashboard) -> some View {
        let pendiente = max(d.esperadoMes - d.cobradoMes, 0)
        let progreso = d.esperadoMes > 0 ? (d.cobradoMes / d.esperadoMes).double : 0
        return TarjetaHero(titulo: "Cobrado este mes", valor: Formato.euros(d.cobradoMes),
                           accesorio: d.tendenciaPct.map { t in
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
            BotonSecundario(titulo: "Informe del mes", icono: "doc.richtext", cargando: generandoInforme) {
                Task { await informe() }
            }
        }
    }

    /// La alerta de ocupación no se muestra: la tarjeta de Ocupación ya lo dice con su color.
    private func alertas(_ d: Dashboard) -> [Alerta] {
        d.alertas.filter { $0.tipo != "OCUPACION" }
    }

    private var saludo: String {
        let nombre = sesion.usuario?.nombre.split(separator: " ").first.map(String.init) ?? ""
        return nombre.isEmpty ? "Inicio" : "Hola, \(nombre)"
    }

    private func cargar() async {
        do {
            async let d = sesion.api.enviar(.dashboard)
            async let n = sesion.api.enviar(.notificacionesNoLeidas)
            let (dashboard, total) = try await (d, n)
            withAnimation(Tema.Movimiento.suave) { estado = .cargado(dashboard) }
            noLeidas = total.total
        } catch let e as APIError {
            if case .noAutorizado = e { return }
            if estado.valor == nil { estado = .error(e.localizedDescription) } else { error = e.localizedDescription }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func contarNoLeidas() async {
        if let total = try? await sesion.api.enviar(.notificacionesNoLeidas) { noLeidas = total.total }
    }

    private func informe() async {
        generandoInforme = true
        defer { generandoInforme = false }
        let mes = Mes.actual
        do {
            let datos = try await sesion.api.descargar(Rutas.informeMensual, consulta: [URLQueryItem(name: "mes", value: mes.texto)])
            documento = DocumentoPDF(titulo: "Informe \(mes.nombre)", datos: datos)
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Barras de ingresos por mes. Al tocar (o arrastrar) un mes se ve su importe arriba;
/// sin tocar, el del mes actual, que va resaltado como en el escritorio.
struct GraficoIngresos: View {
    let meses: [ImporteMes]
    @State private var seleccion: String?
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private var elegido: ImporteMes? {
        meses.first { $0.etiqueta == seleccion } ?? meses.last
    }

    /// Con más de 6 meses las etiquetas no caben: se muestra una de cada dos, acabando en el mes actual.
    private var etiquetasEje: [String] {
        guard meses.count > 6 else { return meses.map(\.etiqueta) }
        return meses.enumerated().filter { (meses.count - 1 - $0.offset) % 2 == 0 }.map(\.element.etiqueta)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.s) {
            if let m = elegido {
                VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                    Text(m == meses.last ? "Este mes" : m.etiqueta.capitalized(with: Formato.locale))
                        .font(Tema.Fuente.nota)
                        .foregroundStyle(Tema.Color.textoSecundario)
                    Text(Formato.euros(m.importe))
                        .font(Tema.Fuente.cifraMediana)
                        .foregroundStyle(Tema.Color.texto)
                        .contentTransition(.numericText())
                }
                .animation(reducirMovimiento ? nil : Tema.Movimiento.suave, value: m)
                .accessibilityHidden(true)
            }
            Chart(meses, id: \.mes) { m in
                BarMark(x: .value("Mes", m.etiqueta), y: .value("Cobrado", m.importe.double), width: .ratio(0.55))
                    .foregroundStyle(m == elegido ? Tema.Color.primario : Tema.Color.primario.opacity(0.35))
                    .clipShape(.rect(cornerRadius: Tema.Radio.pequeno / 2))
                    // VoiceOver recorre los meses uno a uno (y ofrece el gráfico sonoro de Swift Charts).
                    .accessibilityLabel(m.etiqueta.capitalized(with: Formato.locale))
                    .accessibilityValue(Formato.euros(m.importe))
            }
            .chartXSelection(value: $seleccion)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { valor in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3])).foregroundStyle(Tema.Color.borde)
                    AxisValueLabel {
                        if let v = valor.as(Double.self) {
                            Text(Formato.eurosRedondo(v)).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { valor in
                    AxisValueLabel {
                        if let e = valor.as(String.self), etiquetasEje.contains(e) {
                            Text(e).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                        }
                    }
                }
            }
            .accessibilityLabel("Ingresos cobrados por mes")
        }
    }
}

struct FilaActividad: View {
    let actividad: Actividad

    var body: some View {
        HStack(alignment: .top, spacing: Tema.Espacio.s) {
            IconoEtiqueta(icono: actividad.icono, tono: .primario)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(actividad.titulo).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                if let d = actividad.descripcion, !d.isEmpty {
                    Text(d).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario).lineLimit(2)
                }
                if let f = actividad.fecha {
                    Text(f, format: .relative(presentation: .named).locale(Formato.locale))
                        .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Toda la actividad reciente.
struct ActividadView: View {
    @Environment(SesionStore.self) private var sesion
    /// Solo lo que ha hecho el usuario (el historial de su perfil).
    var soloMia = false
    @State private var estado: EstadoCarga<[Actividad]> = .cargando

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { lista in
            List { Section { ForEach(lista) { FilaActividad(actividad: $0) } }.filaLista() }
                .estiloLista()
                .overlay { if lista.isEmpty { EstadoVacio(icono: "clock", titulo: "Sin actividad") } }
        }
        .navigationTitle(soloMia ? "Mi actividad" : "Actividad")
        .task { await cargar() }
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(soloMia ? .miActividad() : .actividad(limite: 50))) }
        catch .noAutorizado {}
        catch { estado = .error(error.localizedDescription) }
    }
}

/// Abre las habitaciones del piso de una habitación (destino de las notificaciones).
struct HabitacionDestinoView: View {
    @Environment(SesionStore.self) private var sesion
    let id: Int
    @State private var estado: EstadoCarga<Habitacion> = .cargando

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { h in
            HabitacionesView(piso: h.piso)
        }
        .task { await cargar() }
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(.habitacion(id: id))) }
        catch .noAutorizado {}
        catch { estado = .error(error.localizedDescription) }
    }
}

/// Destino de las notificaciones de incidencia.
struct IncidenciaDestinoView: View {
    let id: Int

    var body: some View {
        IncidenciaDetalleView(id: id)
    }
}
