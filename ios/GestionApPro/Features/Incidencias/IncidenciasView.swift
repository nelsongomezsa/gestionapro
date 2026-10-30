import SwiftUI

/// Incidencias (IncidenciasController del escritorio). Un inquilino ve las suyas y puede
/// comunicar nuevas, pero no gestionarlas.
struct IncidenciasView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<[Incidencia]> = .cargando
    @State private var filtro: EstadoIncidencia? = .pendiente
    @State private var creando = false
    @State private var paraBorrar: Incidencia?
    @State private var error: String?

    private var gestiona: Bool { sesion.usuario?.rol.gestionaPisos == true }

    var body: some View {
        NavigationStack {
            VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { lista in
                let visibles = filtro == nil ? lista : lista.filter { $0.estado == filtro }
                List {
                    SelectorSegmentado(opciones: EstadoIncidencia.allCases.map { e in
                        (EstadoIncidencia?.some(e), "\(e.nombre) (\(lista.filter { $0.estado == e }.count))")
                    } + [(nil, "Todas (\(lista.count))")], seleccion: $filtro)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    if visibles.isEmpty {
                        EstadoVacio(icono: "checkmark.seal", titulo: "Sin incidencias",
                                    mensaje: filtro == nil ? "No hay incidencias registradas." : "No hay incidencias «\(filtro!.nombre.lowercased())».")
                            .listRowBackground(Color.clear)
                    } else {
                        Section {
                            ForEach(visibles) { i in
                                NavigationLink(value: i.id) { FilaIncidencia(incidencia: i, mostrarEstado: filtro == nil) }
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
            Text(mostrarPiso ? "Hab. \(incidencia.habitacion.numero) · \(incidencia.piso.direccion)" : "Habitación \(incidencia.habitacion.numero)")
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

/// Ficha de una incidencia: estado, coste, datos y borrar.
struct IncidenciaDetalleView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let id: Int
    var alCambiar: () -> Void = {}

    @State private var estado: EstadoCarga<Incidencia> = .cargando
    @State private var coste = 0.0
    @State private var confirmarBorrado = false
    @State private var error: String?

    private var gestiona: Bool { sesion.usuario?.rol.gestionaPisos == true }

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { i in
            List {
                Section {
                    VStack(alignment: .leading, spacing: Tema.Espacio.s) {
                        // El estado se ve en "Progreso", justo debajo.
                        Text(i.descripcion).font(Tema.Fuente.titulo)
                        Text("Comunicada el \(i.fecha.formatted(FormatoFecha.larga))").foregroundStyle(Tema.Color.textoSecundario)
                    }
                    .listRowBackground(Color.clear)
                }
                .filaLista()

                Section("Progreso") {
                    HStack(spacing: Tema.Espacio.xs) {
                        ForEach(EstadoIncidencia.allCases) { e in
                            let hecho = EstadoIncidencia.allCases.firstIndex(of: e)! <= EstadoIncidencia.allCases.firstIndex(of: i.estado)!
                            VStack(spacing: Tema.Espacio.xxs) {
                                Image(systemName: hecho ? "\(e.icono).fill" : e.icono)
                                    .foregroundStyle(hecho ? e.tono.color : Tema.Color.textoSecundario)
                                Text(e.nombre).font(Tema.Fuente.nota)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Estado: \(i.estado.nombre)")
                }
                .filaLista()

                if gestiona, let accion = i.estado.accionSiguiente {
                    Section {
                        BotonPrincipal(titulo: accion, icono: i.estado.siguiente?.icono) { Task { await avanzar(i) } }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Detalles") {
                    LabeledContent("Habitación", value: "Hab. \(i.habitacion.numero)")
                    LabeledContent("Piso", value: "\(i.piso.direccion), \(i.piso.ciudad)")
                    LabeledContent("Inquilino", value: i.inquilino.nombre)
                }
                .filaLista()

                Section {
                    if gestiona {
                        CampoNumerico("Coste de reparación", valor: $coste, sufijo: "€")
                        Button("Guardar coste") { Task { await guardarCoste(i) } }
                            .disabled(Decimal(coste) == i.costeReparacion)
                    } else {
                        LabeledContent("Coste de reparación", value: Formato.euros(i.costeReparacion))
                    }
                } header: {
                    Text("Coste")
                }
                .filaLista()

                if gestiona {
                    Section {
                        Button("Borrar incidencia", role: .destructive) { confirmarBorrado = true }.frame(maxWidth: .infinity)
                    }
                    .filaLista()
                }
            }
            .estiloLista()
            .confirmationDialog("¿Borrar la incidencia?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { Task { await borrar(i) } }
            }
        }
        .navigationTitle("Incidencia")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
        .alertaError($error)
    }

    private func cargar() async {
        do {
            let i = try await sesion.api.enviar(.incidencia(id: id))
            estado = .cargado(i)
            coste = i.costeReparacion.double
        } catch .noAutorizado {
        } catch {
            estado = .error(error.localizedDescription)
        }
    }

    private func avanzar(_ i: Incidencia) async {
        do { estado = .cargado(try await sesion.api.enviar(.cambiarEstado(incidencia: i.id))); alCambiar() }
        catch .noAutorizado {}
        catch { self.error = error.localizedDescription }
    }

    private func guardarCoste(_ i: Incidencia) async {
        let importe = Decimal(string: String(format: "%.2f", coste)) ?? 0
        do { estado = .cargado(try await sesion.api.enviar(.actualizarIncidencia(id: i.id, ActualizarIncidencia(costeReparacion: importe)))); alCambiar() }
        catch .noAutorizado {}
        catch { self.error = error.localizedDescription }
    }

    private func borrar(_ i: Incidencia) async {
        do { _ = try await sesion.api.enviar(.borrarIncidencia(id: i.id)); alCambiar(); cerrar() }
        catch .noAutorizado {}
        catch { self.error = error.localizedDescription }
    }
}

/// Nueva incidencia. El propietario elige piso y habitación; un inquilino solo la describe
/// (la API usa la habitación de su contrato activo).
struct NuevaIncidenciaView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let alGuardar: (Incidencia) -> Void

    @State private var pisos: [Piso] = []
    @State private var habitaciones: [Habitacion] = []
    @State private var idPiso: Int?
    @State private var idHabitacion: Int?
    @State private var descripcion = ""
    @State private var coste = 0.0
    @State private var guardando = false
    @State private var error: String?

    private var gestiona: Bool { sesion.usuario?.rol.gestionaPisos == true }

    var body: some View {
        NavigationStack {
            Form {
                if gestiona {
                    Section("Dónde") {
                        Picker("Piso", selection: $idPiso) {
                            Text("Elige un piso").tag(Int?.none)
                            ForEach(pisos) { Text($0.direccion).tag(Int?.some($0.id)) }
                        }
                        Picker("Habitación", selection: $idHabitacion) {
                            Text("Elige una habitación").tag(Int?.none)
                            ForEach(habitaciones) { h in
                                Text("Hab. \(h.numero)\(h.inquilinoActual.map { " · \($0.nombre)" } ?? "")").tag(Int?.some(h.id))
                            }
                        }
                        .disabled(idPiso == nil)
                    }
                    .filaLista()
                }
                Section {
                    TextField("Describe el problema", text: $descripcion, axis: .vertical).lineLimit(3...6)
                } header: {
                    Text("Qué pasa")
                } footer: {
                    Text("\(descripcion.count)/255")
                }
                .filaLista()
                if gestiona {
                    Section("Coste estimado (opcional)") { CampoNumerico("Coste de reparación", valor: $coste, sufijo: "€") }
                    .filaLista()
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                    .filaLista()
                }
            }
            .estiloLista()
            .navigationTitle("Nueva incidencia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if guardando { ProgressView() } else {
                        Button("Guardar") { Task { await guardar() } }
                            .disabled(descripcion.trimmingCharacters(in: .whitespaces).isEmpty || descripcion.count > 255
                                      || (gestiona && idHabitacion == nil))
                    }
                }
            }
            .task { if gestiona { pisos = (try? await sesion.api.enviar(.pisos)) ?? [] } }
            .onChange(of: idPiso) {
                idHabitacion = nil
                Task { habitaciones = idPiso == nil ? [] : ((try? await sesion.api.enviar(.habitaciones(piso: idPiso))) ?? []) }
            }
        }
    }

    private func guardar() async {
        guardando = true
        defer { guardando = false }
        let req = IncidenciaRequest(idHabitacion: idHabitacion, idInquilino: nil, descripcion: descripcion,
                                    costeReparacion: gestiona && coste > 0 ? Decimal(string: String(format: "%.2f", coste)) : nil)
        do {
            let i = try await sesion.api.enviar(.crearIncidencia(req))
            alGuardar(i)
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
