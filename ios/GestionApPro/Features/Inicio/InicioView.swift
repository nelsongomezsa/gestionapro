import Charts
import SwiftUI

/// Destinos que se abren desde Inicio (incluidos los de las notificaciones).
enum DestinoInicio: Hashable {
    case notificaciones
    case actividad
    case contrato(Int)
    case habitacion(Int)
    case incidencia(Int)
}

/// Inicio (Dashboard del escritorio): KPIs, ingresos de 6 meses, alertas, vencimientos,
/// actividad, informe mensual en PDF y campana de notificaciones.
struct InicioView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<Dashboard> = .cargando
    /// Ruta explícita: las notificaciones abren su pantalla añadiéndola aquí.
    @State private var ruta: [DestinoInicio] = []
    @State private var noLeidas = 0
    @State private var documento: DocumentoPDF?
    @State private var generandoInforme = false
    @State private var error: String?

    private let columnas = [GridItem(.flexible(), spacing: Tema.Espacio.s), GridItem(.flexible(), spacing: Tema.Espacio.s)]

    var body: some View {
        NavigationStack(path: $ruta) {
            VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { d in
                ScrollView {
                    VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                        LazyVGrid(columns: columnas, spacing: Tema.Espacio.s) {
                            TarjetaKPI(titulo: "Cobrado este mes", valor: Formato.euros(d.cobradoMes), icono: "eurosign",
                                       detalle: "de \(Formato.euros(d.esperadoMes)) esperados", tendencia: d.tendenciaPct)
                            TarjetaKPI(titulo: "Cash flow total", valor: Formato.euros(d.cashFlowMensual),
                                       icono: "arrow.left.arrow.right", tono: Tono.signo(d.cashFlowMensual), detalle: "Al mes")
                            TarjetaKPI(titulo: "Ocupación", valor: Formato.porcentaje(d.ocupacion.porcentaje), icono: "chart.pie",
                                       tono: d.ocupacion.tono, detalle: d.ocupacion.salud)
                            TarjetaKPI(titulo: "Habitaciones libres", valor: "\(d.ocupacion.disponibles)",
                                       icono: "door.left.hand.open", tono: .neutro,
                                       detalle: "\(d.ocupacion.mantenimiento) en mantenimiento")
                        }

                        seccion("Ingresos cobrados · últimos 6 meses") {
                            GraficoIngresos(meses: d.ingresosUltimos6Meses).frame(height: 190)
                        }

                        if !d.alertas.isEmpty {
                            seccion("Alertas") {
                                ForEach(d.alertas, id: \.self) { a in
                                    HStack(alignment: .top, spacing: Tema.Espacio.s) {
                                        Image(systemName: a.icono).foregroundStyle(a.tonoVisual.color).frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(a.titulo).font(Tema.Fuente.subtitulo)
                                            Text(a.mensaje).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                                        }
                                    }
                                    .accessibilityElement(children: .combine)
                                    if a != d.alertas.last { Divider() }
                                }
                            }
                        }

                        seccion("Próximos vencimientos (30 días)") {
                            if d.proximosVencimientos.isEmpty {
                                Label("Sin vencimientos en los próximos 30 días", systemImage: "checkmark.seal")
                                    .foregroundStyle(Tema.Color.positivo)
                            }
                            ForEach(d.proximosVencimientos) { c in
                                NavigationLink(value: DestinoInicio.contrato(c.id)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(c.inquilino.nombre).font(Tema.Fuente.subtitulo)
                                            Text("Hab. \(c.habitacion.numero) · \(c.piso.direccion)")
                                                .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario).lineLimit(1)
                                        }
                                        Spacer()
                                        InsigniaEstado(texto: c.diasRestantes == 0 ? "Hoy" : "\(c.diasRestantes) d", tono: c.vencimiento.tono)
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Tema.Color.textoSecundario)
                                    }
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                if c != d.proximosVencimientos.last { Divider() }
                            }
                        }

                        seccion("Actividad reciente") {
                            if d.actividadReciente.isEmpty {
                                Text("Sin actividad registrada todavía.").foregroundStyle(Tema.Color.textoSecundario)
                            }
                            ForEach(d.actividadReciente) { a in
                                FilaActividad(actividad: a)
                                if a != d.actividadReciente.last { Divider() }
                            }
                            NavigationLink(value: DestinoInicio.actividad) {
                                Text("Ver toda la actividad").font(Tema.Fuente.detalle)
                            }
                        }
                    }
                    .padding(Tema.Espacio.m)
                }
                .background(Tema.Color.fondo)
            }
            .navigationTitle(saludo)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Task { await informe() } } label: {
                        if generandoInforme { ProgressView() } else { Label("Informe del mes", systemImage: "doc.richtext") }
                    }
                    .disabled(generandoInforme)
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: DestinoInicio.notificaciones) {
                        Image(systemName: noLeidas > 0 ? "bell.badge.fill" : "bell")
                            .symbolRenderingMode(.multicolor)
                            .overlay(alignment: .topTrailing) {
                                if noLeidas > 0 {
                                    Text(noLeidas > 99 ? "99+" : "\(noLeidas)")
                                        .font(.caption2.bold()).foregroundStyle(.white)
                                        .padding(.horizontal, 4).background(Tema.Color.negativo, in: .capsule)
                                        .offset(x: 10, y: -8)
                                }
                            }
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
                case let .contrato(id): ContratoDetalleView(id: id)
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

    private var saludo: String {
        let nombre = sesion.usuario?.nombre.split(separator: " ").first.map(String.init) ?? ""
        return nombre.isEmpty ? "Inicio" : "Hola, \(nombre)"
    }

    private func cargar() async {
        do {
            async let d = sesion.api.enviar(.dashboard)
            async let n = sesion.api.enviar(.notificacionesNoLeidas)
            let (dashboard, total) = try await (d, n)
            estado = .cargado(dashboard)
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

    private func seccion<Contenido: View>(_ titulo: String, @ViewBuilder contenido: () -> Contenido) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            Text(titulo).estiloEtiqueta().padding(.horizontal, Tema.Espacio.xxs)
            VStack(alignment: .leading, spacing: Tema.Espacio.s) { contenido() }.tarjeta()
        }
    }
}

/// Barras de ingresos por mes; el mes actual en el color de la marca (como el escritorio).
struct GraficoIngresos: View {
    let meses: [ImporteMes]

    var body: some View {
        Chart(meses, id: \.mes) { m in
            BarMark(x: .value("Mes", m.etiqueta), y: .value("Cobrado", m.importe.double))
                .foregroundStyle(m == meses.last ? Tema.Color.primario.gradient : Tema.Color.primario.opacity(0.35).gradient)
                .clipShape(.rect(cornerRadius: 6))
        }
        .chartYAxis {
            AxisMarks { valor in
                AxisGridLine()
                AxisValueLabel { if let v = valor.as(Double.self) { Text(Formato.eurosRedondo(v)) } }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ingresos cobrados por mes")
        .accessibilityValue(meses.map { "\($0.etiqueta): \(Formato.euros($0.importe))" }.joined(separator: ", "))
    }
}

struct FilaActividad: View {
    let actividad: Actividad

    var body: some View {
        HStack(alignment: .top, spacing: Tema.Espacio.s) {
            Image(systemName: actividad.icono).foregroundStyle(Tema.Color.primario).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(actividad.titulo).font(Tema.Fuente.subtitulo)
                if let d = actividad.descripcion, !d.isEmpty {
                    Text(d).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario).lineLimit(2)
                }
            }
            Spacer()
            if let f = actividad.fecha {
                Text(f, format: .relative(presentation: .named).locale(Formato.locale))
                    .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Toda la actividad reciente.
struct ActividadView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<[Actividad]> = .cargando

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { lista in
            List(lista) { FilaActividad(actividad: $0) }
                .overlay { if lista.isEmpty { EstadoVacio(icono: "clock", titulo: "Sin actividad") } }
        }
        .navigationTitle("Actividad")
        .task { await cargar() }
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(.actividad(limite: 50))) }
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
