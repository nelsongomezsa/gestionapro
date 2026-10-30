import PhotosUI
import SwiftUI

/// Gastos reales de un piso por año: alta con categoría, factura (foto o PDF) y total deducible.
/// Los de incidencias resueltas con coste aparecen solos.
struct GastosView: View {
    @Environment(SesionStore.self) private var sesion
    let piso: PisoBreve

    @State private var anio = Calendar.current.component(.year, from: .now)
    @State private var estado: EstadoCarga<ResumenGastos> = .cargando
    @State private var editando: Gasto?
    @State private var creando = false
    @State private var paraBorrar: Gasto?
    @State private var error: String?

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { r in
            List {
                Section {
                    HStack {
                        Button { anio -= 1 } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Año anterior")
                        Spacer()
                        Text(String(anio)).font(Tema.Fuente.tituloSeccion).monospacedDigit()
                        Spacer()
                        Button { anio += 1 } label: { Image(systemName: "chevron.right") }
                            .disabled(anio >= Calendar.current.component(.year, from: .now))
                            .accessibilityLabel("Año siguiente")
                    }
                    .buttonStyle(.borderless)
                    ParDatos {
                        DatoCompacto(titulo: "Total del año", valor: Formato.euros(r.total))
                    } derecha: {
                        DatoCompacto(titulo: "Deducible", valor: Formato.euros(r.totalDeducible))
                    }
                }
                .filaLista()

                if r.lista.isEmpty {
                    EstadoVacio(icono: "eurosign.square", titulo: "Sin gastos en \(String(anio))",
                                mensaje: "Añade comunidad, IBI, seguro, reparaciones… Con gastos reales, la rentabilidad es más exacta.")
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(r.lista) { g in
                            Button { editando = g } label: { FilaGasto(gasto: g).contentShape(.rect) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("filaGasto")
                                .swipeActions {
                                    if g.idIncidencia == nil {
                                        Button("Borrar", systemImage: "trash", role: .destructive) { paraBorrar = g }
                                    }
                                }
                        }
                    } header: {
                        Text(r.lista.count == 1 ? "1 gasto" : "\(r.lista.count) gastos")
                    } footer: {
                        Text("Los gastos de incidencias resueltas con coste se añaden solos.")
                    }
                    .filaLista()
                }
            }
            .estiloLista()
        }
        .navigationTitle("Gastos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nuevo gasto", systemImage: "plus") { creando = true }
                    .accessibilityIdentifier("botonNuevoGasto")
            }
        }
        .sheet(isPresented: $creando) {
            NavigationStack { GastoFormView(piso: piso, gasto: nil) { Task { await cargar() } } }
        }
        .sheet(item: $editando) { g in
            NavigationStack { GastoFormView(piso: piso, gasto: g) { Task { await cargar() } } }
        }
        .confirmationDialog("¿Borrar el gasto de \(paraBorrar.map { Formato.euros($0.importe) } ?? "")?",
                            isPresented: Binding(get: { paraBorrar != nil }, set: { if !$0 { paraBorrar = nil } }),
                            titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { if let g = paraBorrar { Task { await borrar(g) } } }
        }
        .alertaError($error)
        .refreshable { await cargar() }
        .task(id: anio) { await cargar() }
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(.gastos(piso: piso.id, anio: anio))) }
        catch .noAutorizado {}
        catch { if estado.valor == nil { estado = .error(error.localizedDescription) } else { self.error = error.localizedDescription } }
    }

    private func borrar(_ g: Gasto) async {
        do {
            _ = try await sesion.api.enviar(.borrarGasto(g.id))
            await cargar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct FilaGasto: View {
    let gasto: Gasto

    var body: some View {
        HStack(alignment: .top, spacing: Tema.Espacio.s) {
            IconoEtiqueta(icono: gasto.categoria.icono, tono: gasto.idIncidencia != nil ? .aviso : .primario)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(gasto.concepto).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                Text(detalle).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
            Spacer(minLength: Tema.Espacio.xs)
            Text(Formato.euros(gasto.importe)).font(Tema.Fuente.cifraPequena).foregroundStyle(Tema.Color.texto)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var detalle: String {
        var partes = [gasto.categoria.nombre, gasto.fecha.formatted(FormatoFecha.corta)]
        if let h = gasto.numeroHabitacion { partes.append("Hab. \(h)") }
        if gasto.tieneFactura { partes.append("con factura") }
        if !gasto.deducible { partes.append("no deducible") }
        return partes.joined(separator: " · ")
    }
}

/// Alta o edición de un gasto, con su factura (foto o PDF).
struct GastoFormView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let piso: PisoBreve
    let gasto: Gasto?
    let alGuardar: () -> Void

    @State private var categoria: CategoriaGasto = .comunidad
    @State private var concepto = ""
    @State private var importe: Decimal?
    @State private var fecha = Date.now
    @State private var deducible = true
    @State private var habitaciones: [Habitacion] = []
    @State private var idHabitacion: Int?
    @State private var foto: PhotosPickerItem?
    @State private var importandoPDF = false
    @State private var factura: (datos: Data, tipo: String, nombre: String)?
    @State private var documento: DocumentoPDF?
    @State private var imagenFactura: UIImage?
    @State private var guardando = false
    @State private var error: String?

    private var deIncidencia: Bool { gasto?.idIncidencia != nil }
    private var valido: Bool { !concepto.trimmingCharacters(in: .whitespaces).isEmpty && (importe ?? 0) > 0 }

    var body: some View {
        Form {
            Section {
                Picker("Categoría", selection: $categoria) {
                    ForEach(CategoriaGasto.allCases) { Label($0.nombre, systemImage: $0.icono).tag($0) }
                }
                TextField("Concepto", text: $concepto)
                    .accessibilityIdentifier("campoConcepto")
                TextField("Importe", value: $importe, format: .currency(code: "EUR").locale(Formato.locale))
                    .keyboardType(.decimalPad)
                    .disabled(deIncidencia)
                    .accessibilityIdentifier("campoImporteGasto")
                DatePicker("Fecha", selection: $fecha, in: ...Date.now, displayedComponents: .date)
            } footer: {
                if deIncidencia { Text("Viene de una incidencia: su importe se cambia en la incidencia.") }
            }
            .filaLista()
            Section {
                Picker("Habitación", selection: $idHabitacion) {
                    Text("Todo el piso").tag(Int?.none)
                    ForEach(habitaciones) { h in Text("Habitación \(h.numero)").tag(Int?.some(h.id)) }
                }
                Toggle("Deducible en el IRPF", isOn: $deducible)
            } footer: {
                Text("Orientativo: los gastos de reparación y conservación, comunidad, IBI, seguro o suministros que paga el propietario suelen ser deducibles; el mobiliario se amortiza.")
            }
            .filaLista()
            Section("Factura") {
                if let imagen = imagenFactura {
                    Image(uiImage: imagen).resizable().scaledToFit().frame(maxHeight: 220)
                        .clipShape(.rect(cornerRadius: Tema.Radio.medio))
                        .accessibilityLabel("Foto de la factura")
                } else if factura?.tipo == "application/pdf" {
                    Label(factura?.nombre ?? "Factura.pdf", systemImage: "doc.richtext")
                } else if gasto?.tieneFactura == true {
                    Button { Task { await verFactura() } } label: { Label("Ver factura", systemImage: "doc.text.magnifyingglass") }
                }
                // La etiqueta del selector es un cierre Sendable: se le pasa el texto ya calculado.
                let textoFoto = gasto?.tieneFactura == true || factura != nil ? "Cambiar por una foto" : "Foto de la factura"
                PhotosPicker(selection: $foto, matching: .images) {
                    Label(textoFoto, systemImage: "camera")
                }
                Button { importandoPDF = true } label: { Label("Elegir un PDF", systemImage: "doc.badge.plus") }
            }
            .filaLista()
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                .filaLista()
            }
        }
        .estiloLista()
        .navigationTitle(gasto == nil ? "Nuevo gasto" : "Editar gasto")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
            ToolbarItem(placement: .confirmationAction) {
                if guardando { ProgressView() } else {
                    Button("Guardar") { Task { await guardar() } }.disabled(!valido)
                }
            }
        }
        .onChange(of: foto) { _, item in
            guard let item else { return }
            Task {
                if let datos = try? await item.loadTransferable(type: Data.self), let jpeg = FotoPreparada.jpeg(datos) {
                    factura = (jpeg, "image/jpeg", "factura.jpg")
                    imagenFactura = UIImage(data: jpeg)
                } else {
                    error = "No se pudo leer la foto"
                }
            }
        }
        .fileImporter(isPresented: $importandoPDF, allowedContentTypes: [.pdf]) { resultado in
            guard case let .success(url) = resultado else { return }
            let acceso = url.startAccessingSecurityScopedResource()
            defer { if acceso { url.stopAccessingSecurityScopedResource() } }
            if let datos = try? Data(contentsOf: url), datos.count <= 10 * 1024 * 1024 {
                factura = (datos, "application/pdf", url.lastPathComponent)
                imagenFactura = nil
            } else {
                error = "No se pudo leer el PDF (máximo 10 MB)"
            }
        }
        .visorPDF($documento)
        .task { await preparar() }
    }

    private func preparar() async {
        if let g = gasto {
            categoria = g.categoria
            concepto = g.concepto
            importe = g.importe
            fecha = g.fecha
            deducible = g.deducible
            idHabitacion = g.idHabitacion
        }
        habitaciones = (try? await sesion.api.enviar(.habitaciones(piso: piso.id))) ?? []
    }

    private func verFactura() async {
        guard let g = gasto else { return }
        do {
            let datos = try await sesion.api.descargar(Rutas.facturaGasto(g.id), tipo: "*/*")
            if datos.starts(with: Data("%PDF".utf8)) {
                documento = DocumentoPDF(titulo: "Factura", datos: datos)
            } else {
                imagenFactura = UIImage(data: datos)
            }
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func guardar() async {
        guard let importe else { return }
        guardando = true
        defer { guardando = false }
        let req = GastoRequest(idPiso: piso.id, idHabitacion: idHabitacion, categoria: categoria,
                               concepto: concepto.trimmingCharacters(in: .whitespaces), importe: importe,
                               fecha: FechaAPI.texto(fecha), deducible: deducible)
        do {
            let guardado = try await sesion.api.enviar(gasto.map { .actualizarGasto($0.id, req) } ?? .crearGasto(req))
            if let f = factura {
                _ = try await sesion.api.subir(Rutas.facturaGasto(guardado.id), archivo: f.datos, nombre: f.nombre, tipo: f.tipo,
                                               respuesta: Gasto.self)
            }
            alGuardar()
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
