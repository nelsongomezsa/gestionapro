import SwiftUI

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
    @State private var clasificacion: ClasificacionIncidencia?
    @State private var clasificando = false

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
                    if gestiona && descripcion.count >= 10 {
                        if clasificando {
                            HStack { ProgressView(); Text("Clasificando…") }
                        } else if let c = clasificacion {
                            Label("\(c.categoria.capitalized) · urgencia \(c.urgencia.lowercased()). \(c.motivo)", systemImage: "sparkles")
                                .font(Tema.Fuente.detalle)
                                .foregroundStyle(c.urgencia == "ALTA" ? Tema.Color.negativo : Tema.Color.textoSecundario)
                        } else {
                            Button { Task { await clasificar() } } label: {
                                Label("Sugerir categoría y urgencia", systemImage: "sparkles")
                            }
                        }
                    }
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

    /// Sugerencia del asistente (si está activo); solo informa, no cambia nada.
    private func clasificar() async {
        clasificando = true
        defer { clasificando = false }
        do { clasificacion = try await sesion.api.enviar(.clasificarIncidencia(descripcion)) }
        catch .noAutorizado {}
        catch { self.error = error.localizedDescription }
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
