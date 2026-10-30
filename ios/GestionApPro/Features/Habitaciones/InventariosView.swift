import PhotosUI
import SwiftUI

/// Inventarios de entrada y salida de una habitación. El propietario los crea, añade fotos y
/// los exporta en PDF para firmarlos; el inquilino ve los de su contrato.
struct InventariosView: View {
    @Environment(SesionStore.self) private var sesion
    let idHabitacion: Int
    let titulo: String

    @State private var estado: EstadoCarga<[Inventario]> = .cargando
    @State private var creando = false

    private var gestiona: Bool { sesion.usuario?.rol.gestionaPisos == true }

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { lista in
            List {
                if lista.isEmpty {
                    EstadoVacio(icono: "checklist", titulo: "Sin inventarios",
                                mensaje: gestiona ? "Haz uno al entregar la habitación y otro al recogerla." : "Tu propietario aún no ha hecho ninguno.")
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(lista) { i in
                        NavigationLink(value: i) {
                            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                                Text("\(i.tipo.nombre) · \(i.fecha.formatted(FormatoFecha.larga))").font(Tema.Fuente.subtitulo)
                                Text(resumen(i)).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                            }
                        }
                        .accessibilityIdentifier("filaInventario")
                    }
                }
                .filaLista()
            }
            .estiloLista()
        }
        .navigationTitle(titulo)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Inventario.self) { InventarioDetalleView(inventario: $0) { Task { await cargar() } } }
        .toolbar {
            if gestiona {
                ToolbarItem(placement: .primaryAction) {
                    Button("Nuevo inventario", systemImage: "plus") { creando = true }
                        .accessibilityIdentifier("botonNuevoInventario")
                }
            }
        }
        .sheet(isPresented: $creando) {
            NavigationStack { NuevoInventarioView(idHabitacion: idHabitacion) { Task { await cargar() } } }
        }
        .refreshable { await cargar() }
        .task { await cargar() }
    }

    private func resumen(_ i: Inventario) -> String {
        let danados = i.elementos.filter { $0.estado == .danado }.count
        var partes = [i.elementos.count == 1 ? "1 elemento" : "\(i.elementos.count) elementos"]
        if danados > 0 { partes.append(danados == 1 ? "1 dañado" : "\(danados) dañados") }
        if let q = i.inquilino { partes.append(q) }
        return partes.joined(separator: " · ")
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(.inventarios(habitacion: idHabitacion))) }
        catch .noAutorizado {}
        catch { estado = .error(error.localizedDescription) }
    }
}

/// Detalle: elementos con su estado y foto, PDF para firmar y borrar.
struct InventarioDetalleView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State var inventario: Inventario
    let alCambiar: () -> Void

    @State private var imagenes: [Int: UIImage] = [:]
    @State private var fotoPara: Int?
    @State private var seleccion: PhotosPickerItem?
    @State private var documento: DocumentoPDF?
    @State private var confirmarBorrado = false
    @State private var error: String?

    private var gestiona: Bool { sesion.usuario?.rol.gestionaPisos == true }

    var body: some View {
        List {
            Section {
                ForEach(inventario.elementos) { e in
                    HStack(alignment: .top, spacing: Tema.Espacio.s) {
                        VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
                            Text(e.nombre).font(Tema.Fuente.subtitulo)
                            InsigniaEstado(texto: e.estado.nombre, tono: e.estado.tono)
                            if let o = e.observaciones {
                                Text(o).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                            }
                        }
                        Spacer(minLength: Tema.Espacio.xs)
                        if let imagen = imagenes[e.id] {
                            Image(uiImage: imagen).resizable().scaledToFill()
                                .frame(width: Tema.Tamano.avatarGrande, height: Tema.Tamano.avatarGrande)
                                .clipShape(.rect(cornerRadius: Tema.Radio.medio))
                                .accessibilityLabel("Foto de \(e.nombre)")
                        } else if gestiona {
                            Button { fotoPara = e.id } label: {
                                Image(systemName: "camera").font(Tema.Fuente.subtitulo)
                                    .frame(width: Tema.Tamano.botonRedondo, height: Tema.Tamano.botonRedondo)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Añadir foto de \(e.nombre)")
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(inventario.inquilino.map { "\(inventario.fecha.formatted(FormatoFecha.larga)) · \($0)" }
                     ?? inventario.fecha.formatted(FormatoFecha.larga))
            }
            .filaLista()
            if let o = inventario.observaciones {
                Section("Observaciones") { Text(o) }.filaLista()
            }
            Section {
                Button { Task { await abrirPDF() } } label: {
                    Label("PDF para firmar", systemImage: "doc.richtext")
                }
                .accessibilityIdentifier("botonPdfInventario")
                if gestiona {
                    Button("Borrar inventario", role: .destructive) { confirmarBorrado = true }
                }
            }
            .filaLista()
        }
        .estiloLista()
        .navigationTitle("Inventario de \(inventario.tipo.nombre.lowercased())")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: Binding(get: { fotoPara != nil }, set: { if !$0 && seleccion == nil { fotoPara = nil } }),
                      selection: $seleccion, matching: .images)
        .onChange(of: seleccion) { _, item in
            guard let item, let id = fotoPara else { return }
            Task { await subirFoto(item, elemento: id) }
        }
        .confirmationDialog("¿Borrar el inventario?", isPresented: $confirmarBorrado, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { Task { await borrar() } }
        }
        .visorPDF($documento)
        .alertaError($error)
        .task { await cargarFotos() }
    }

    private func cargarFotos() async {
        for e in inventario.elementos where e.tieneFoto && imagenes[e.id] == nil {
            if let datos = try? await sesion.api.descargar(Rutas.fotoElemento(e.id), tipo: "image/*") {
                imagenes[e.id] = UIImage(data: datos)
            }
        }
    }

    private func subirFoto(_ item: PhotosPickerItem, elemento id: Int) async {
        defer {
            seleccion = nil
            fotoPara = nil
        }
        guard let datos = try? await item.loadTransferable(type: Data.self), let jpeg = FotoPreparada.jpeg(datos) else {
            error = "No se pudo leer la foto"
            return
        }
        do {
            inventario = try await sesion.api.subir(Rutas.fotoElemento(id), archivo: jpeg, nombre: "foto.jpg", tipo: "image/jpeg",
                                                    respuesta: Inventario.self)
            imagenes[id] = UIImage(data: jpeg)
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func abrirPDF() async {
        do {
            documento = DocumentoPDF(titulo: "Inventario \(inventario.tipo.nombre.lowercased()) · hab. \(inventario.numeroHabitacion)",
                                     datos: try await sesion.api.descargar(Rutas.pdfInventario(inventario.id)))
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func borrar() async {
        do {
            _ = try await sesion.api.enviar(.borrarInventario(inventario.id))
            alCambiar()
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Alta: tipo, fecha, contrato de la habitación y elementos (con una lista propuesta que se puede cambiar).
struct NuevoInventarioView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let idHabitacion: Int
    let alCrear: () -> Void

    struct Fila: Identifiable {
        let id = UUID()
        var nombre: String
        var estado: EstadoElemento = .bueno
        var observaciones = ""
    }

    static let propuestos = ["Cama", "Colchón", "Armario", "Escritorio", "Silla", "Paredes", "Suelo", "Ventana", "Puerta y cerradura", "Llaves"]

    @State private var tipo: TipoInventario = .entrada
    @State private var fecha = Date.now
    @State private var contratos: [Contrato] = []
    @State private var idContrato: Int?
    @State private var filas = propuestos.map { Fila(nombre: $0) }
    @State private var observaciones = ""
    @State private var guardando = false
    @State private var error: String?

    private var valido: Bool { filas.contains { !$0.nombre.trimmingCharacters(in: .whitespaces).isEmpty } }

    var body: some View {
        Form {
            Section {
                Picker("Tipo", selection: $tipo) {
                    ForEach(TipoInventario.allCases) { Text($0.nombre).tag($0) }
                }
                .pickerStyle(.segmented)
                DatePicker("Fecha", selection: $fecha, in: ...Date.now, displayedComponents: .date)
                Picker("Contrato", selection: $idContrato) {
                    Text("Sin contrato").tag(Int?.none)
                    ForEach(contratos) { c in Text(c.inquilino.nombre).tag(Int?.some(c.id)) }
                }
            } footer: {
                Text("Con contrato, el inquilino también lo ve en la app.")
            }
            .filaLista()
            Section {
                ForEach($filas) { $f in
                    VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                        TextField("Elemento", text: $f.nombre).font(Tema.Fuente.subtitulo)
                        Picker("Estado", selection: $f.estado) {
                            ForEach(EstadoElemento.allCases) { Text($0.nombre).tag($0) }
                        }
                        if f.estado == .danado || f.estado == .usado || !f.observaciones.isEmpty {
                            TextField("Observaciones", text: $f.observaciones)
                        }
                    }
                }
                .onDelete { filas.remove(atOffsets: $0) }
                Button("Añadir elemento", systemImage: "plus") { filas.append(Fila(nombre: "")) }
            } header: {
                Text("Elementos (\(filas.count))")
            } footer: {
                Text("Desliza para quitar uno. Las fotos se añaden después, desde el inventario.")
            }
            .filaLista()
            Section("Observaciones") {
                TextField("Observaciones generales", text: $observaciones, axis: .vertical).lineLimit(2...5)
            }
            .filaLista()
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                .filaLista()
            }
        }
        .estiloLista()
        .navigationTitle("Nuevo inventario")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
            ToolbarItem(placement: .confirmationAction) {
                if guardando { ProgressView() } else {
                    Button("Guardar") { Task { await guardar() } }.disabled(!valido)
                }
            }
        }
        .task { await cargarContratos() }
    }

    private func cargarContratos() async {
        guard let todos = try? await sesion.api.enviar(.contratos()) else { return }
        contratos = todos.filter { $0.habitacion.id == idHabitacion }
        idContrato = contratos.first(where: \.activo)?.id
    }

    private func guardar() async {
        guardando = true
        defer { guardando = false }
        let elementos = filas
            .filter { !$0.nombre.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { InventarioRequest.Elemento(nombre: $0.nombre.trimmingCharacters(in: .whitespaces), estado: $0.estado,
                                              observaciones: $0.observaciones.isEmpty ? nil : $0.observaciones) }
        let req = InventarioRequest(tipo: tipo, fecha: FechaAPI.texto(fecha), idContrato: idContrato,
                                    observaciones: observaciones.isEmpty ? nil : observaciones, elementos: elementos)
        do {
            _ = try await sesion.api.enviar(.crearInventario(habitacion: idHabitacion, req))
            alCrear()
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
