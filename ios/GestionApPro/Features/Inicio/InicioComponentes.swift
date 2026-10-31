import Charts
import SwiftUI

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
