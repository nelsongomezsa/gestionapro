import SwiftUI

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
    @State private var modeloFotos = ModeloFotos()
    @State private var chat = false

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

                SeccionFotos(modelo: modeloFotos)

                Section {
                    Button { chat = true } label: {
                        Label(gestiona ? "Escribir al inquilino sobre esta incidencia" : "Escribir al propietario sobre esta incidencia",
                              systemImage: "bubble.left.and.bubble.right")
                    }
                    .accessibilityIdentifier("botonMensajesIncidencia")
                }
                .filaLista()

                Section("Detalles") {
                    LabeledContent(i.habitacion.unidad.nombre, value: "\(i.habitacion.etiqueta)")
                    LabeledContent("Inmueble", value: "\(i.piso.direccion), \(i.piso.ciudad)")
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
        .fotosIncidencia(modeloFotos, incidencia: id, api: sesion.api, puedeBorrarTodas: gestiona)
        .sheet(isPresented: $chat) {
            NavigationStack {
                ChatView(hilo: .incidencia(id),
                         titulo: gestiona ? estado.valor?.inquilino.nombre : String(localized: "Mi propietario"))
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { chat = false } } }
            }
        }
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
