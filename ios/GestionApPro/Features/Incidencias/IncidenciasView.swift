import SwiftUI

/// Incidencias (IncidenciasController del escritorio). Un inquilino ve las suyas y puede
/// comunicar nuevas, pero no gestionarlas.
struct IncidenciasView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<[Incidencia]> = .cargando
    @State private var filtro: FiltroIncidencias
    @State private var creando = false
    @State private var paraBorrar: Incidencia?
    @State private var error: String?
    @AppStorage(Agrupacion.clave("incidencias")) private var agrupacion: Agrupacion = .todos

    /// En su propia pestaña lleva su pila; dentro de Más (o de Inicio) usa la de fuera.
    var enPila: Bool

    init(enPila: Bool = true, filtro: FiltroIncidencias = .pendientes) {
        self.enPila = enPila
        _filtro = State(initialValue: filtro)
    }

    private var gestiona: Bool { sesion.usuario?.rol.gestionaPisos == true }

    var body: some View {
        if enPila { NavigationStack { contenido } } else { contenido }
    }

    private var contenido: some View {
        Group {
            VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { lista in
                let visibles = lista.filter { filtro.incluye($0.estado) }
                List {
                    SelectorSegmentado(opciones: FiltroIncidencias.allCases.map { f in
                        (f, "\(f.nombre) (\(lista.filter { f.incluye($0.estado) }.count))")
                    }, seleccion: $filtro)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    SelectorAgrupacion(agrupacion: $agrupacion)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())

                    if visibles.isEmpty {
                        EstadoVacio(icono: "checkmark.seal", titulo: "Sin incidencias",
                                    mensaje: filtro == .todas ? "No hay incidencias registradas." : "No hay incidencias «\(filtro.nombre.lowercased())».")
                            .listRowBackground(Color.clear)
                    } else if agrupacion == .porPiso {
                        SeccionesPorPiso(grupos: AgrupadorPiso.agrupar(visibles) { $0.piso }, pantalla: "incidencias",
                                         resumen: { ResumenPorPiso.incidencias($0.elementos) }) { fila($0, mostrarPiso: false) }
                    } else {
                        Section {
                            ForEach(visibles) { fila($0, mostrarPiso: true) }
                        } footer: {
                            if gestiona { Text("Desliza a la derecha para avanzar el estado y a la izquierda para borrar.") }
                        }
                        .filaLista()
                    }
                }
                .estiloLista()
            }
            .navigationTitle("Incidencias")
            .navigationDestination(for: Int.self) { IncidenciaDetalleView(id: $0) { Task { await cargar() } } }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Nueva incidencia", systemImage: "plus") { creando = true }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .datosCambiados)) { _ in Task { await cargar() } }
            .refreshable { await cargar() }
            .task { await cargar() }
            .sheet(isPresented: $creando) { NuevaIncidenciaView { _ in Task { await cargar() } } }
            .confirmationDialog("¿Borrar la incidencia?", isPresented: Binding(get: { paraBorrar != nil }, set: { if !$0 { paraBorrar = nil } }),
                                titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { if let i = paraBorrar { Task { await borrar(i) } } }
            } message: {
                Text(paraBorrar?.descripcion ?? "")
            }
            .alertaError($error)
        }
    }

    private func fila(_ i: Incidencia, mostrarPiso: Bool) -> some View {
        NavigationLink(value: i.id) { FilaIncidencia(incidencia: i, mostrarEstado: filtro.variosEstados, mostrarPiso: mostrarPiso) }
            .accessibilityIdentifier("filaIncidencia")
            .swipeActions(edge: .leading) {
                if gestiona, let accion = i.estado.accionSiguiente, let sig = i.estado.siguiente {
                    Button(accion, systemImage: sig.icono) { Task { await avanzar(i) } }.tint(sig.tono.color)
                }
            }
            .swipeActions(edge: .trailing) {
                if gestiona {
                    Button("Borrar", systemImage: "trash", role: .destructive) { paraBorrar = i }
                }
            }
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(.incidencias())) }
        catch .noAutorizado {}
        catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) } else { self.error = error.localizedDescription }
        }
    }

    private func avanzar(_ i: Incidencia) async {
        do { _ = try await sesion.api.enviar(.cambiarEstado(incidencia: i.id)); await cargar() }
        catch .noAutorizado {}
        catch { self.error = error.localizedDescription }
    }

    private func borrar(_ i: Incidencia) async {
        do { _ = try await sesion.api.enviar(.borrarIncidencia(id: i.id)); await cargar() }
        catch .noAutorizado {}
        catch { self.error = error.localizedDescription }
    }
}

struct FilaIncidencia: View {
    let incidencia: Incidencia
    /// false cuando la lista ya está filtrada por un estado: la insignia sería la misma en todas.
    var mostrarEstado = true
    /// false dentro del detalle de un piso: la dirección ya está en la cabecera.
    var mostrarPiso = true

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
            HStack(alignment: .top) {
                Text(incidencia.descripcion).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto).lineLimit(3)
                Spacer()
                if mostrarEstado {
                    InsigniaEstado(texto: incidencia.estado.nombre, tono: incidencia.estado.tono, icono: incidencia.estado.icono)
                }
            }
            Text(mostrarPiso ? "\(incidencia.habitacion.etiqueta) · \(incidencia.piso.direccion)" : "\(incidencia.habitacion.titulo)")
                .font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
            // El nombre completo, sin recortar: comparte línea con la antigüedad y pasa a otra si no cabe.
            Text([incidencia.inquilino.nombre,
                  incidencia.dias == 0 ? "hoy" : "hace \(incidencia.dias) días",
                  incidencia.costeReparacion > 0 ? "reparación \(Formato.euros(incidencia.costeReparacion))" : nil]
                    .compactMap { $0 }.joined(separator: " · "))
                .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
        }
        .padding(.vertical, Tema.Espacio.linea)
        .accessibilityElement(children: .combine)
    }
}
