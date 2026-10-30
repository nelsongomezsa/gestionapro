import SwiftUI

/// Estado de la fianza de un contrato. Lo guarda la pantalla (no la sección): dentro de una
/// List, un .task o un .sheet puestos en un Group se repetirían en cada fila.
@MainActor @Observable
final class ModeloFianza {
    enum Hoja: String, Identifiable {
        case editar, devolver
        var id: String { rawValue }
    }

    /// nil mientras carga; .some(nil) si el contrato no tiene fianza (404).
    var fianza: Fianza??
    /// La carga falló por otro motivo: no se puede decir que no tenga fianza.
    var fallo: String?
    var hoja: Hoja?
    var error: String?

    func cargar(contrato id: Int, con api: APIClient) async {
        fianza = nil
        fallo = nil
        do {
            fianza = .some(try await api.enviar(.fianza(contrato: id)))
        } catch .respuesta(status: 404, _) {
            fianza = .some(nil)
        } catch .noAutorizado {
        } catch {
            fallo = error.localizedDescription
        }
    }
}

/// Sección "Fianza" del detalle de un contrato (y de "Mi alquiler", solo lectura).
struct SeccionFianza: View {
    @Environment(SesionStore.self) private var sesion
    let modelo: ModeloFianza
    let idContrato: Int
    var editable = false

    var body: some View {
        switch modelo.fianza {
        case .none:
            Section("Fianza") {
                if let fallo = modelo.fallo {
                    Label(fallo, systemImage: "exclamationmark.triangle").foregroundStyle(Tema.Color.negativo)
                    Button("Reintentar") { Task { await modelo.cargar(contrato: idContrato, con: sesion.api) } }
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .filaLista()
        case .some(.none):
            if editable {
                Section("Fianza") {
                    Button { modelo.hoja = .editar } label: { Label("Añadir fianza", systemImage: "plus.circle") }
                        .accessibilityIdentifier("botonAnadirFianza")
                }
                .filaLista()
            }
        case let .some(.some(f)):
            Section {
                FilaMetrica(titulo: "Importe", valor: Formato.euros(f.importe),
                            nota: f.fechaCobro.map { "Entregada el \($0.formatted(FormatoFecha.larga))" })
                if let d = f.fechaDeposito {
                    let datos = [f.organismoDeposito, f.referenciaDeposito.map { "ref. \($0)" }].compactMap { $0 }
                    FilaMetrica(titulo: "Depósito", valor: d.formatted(FormatoFecha.corta),
                                nota: datos.isEmpty ? nil : datos.joined(separator: " · "))
                }
                if let d = f.fechaDevolucion, let devuelto = f.importeDevuelto {
                    FilaMetrica(titulo: "Devuelto el \(d.formatted(FormatoFecha.corta))", valor: Formato.euros(devuelto),
                                tono: .positivo)
                    if f.retenido > 0 {
                        FilaMetrica(titulo: "Retenido", valor: Formato.euros(f.retenido), nota: f.motivoRetencion, tono: .aviso)
                    }
                }
                if let n = f.notas { Text(n).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario) }
                if editable {
                    Button { modelo.hoja = .editar } label: { Label("Editar fianza", systemImage: "pencil") }
                    if f.fechaDevolucion == nil {
                        Button { modelo.hoja = .devolver } label: {
                            Label("Registrar devolución", systemImage: "arrow.uturn.backward.circle")
                        }
                        .accessibilityIdentifier("botonDevolverFianza")
                    }
                }
            } header: {
                HStack {
                    Text("Fianza")
                    Spacer()
                    InsigniaEstado(texto: f.estado.nombre, tono: f.estado.tono)
                }
            }
            .filaLista()
        }
    }
}

extension View {
    /// Carga la fianza y presenta sus formularios; se pone en la pantalla, fuera de la List.
    func fianza(_ modelo: ModeloFianza, contrato id: Int?, renta: Decimal, api: APIClient) -> some View {
        @Bindable var modelo = modelo
        return self
            .task(id: id) { if let id { await modelo.cargar(contrato: id, con: api) } }
            .sheet(item: $modelo.hoja) { h in
                NavigationStack {
                    if let id {
                        switch h {
                        case .editar:
                            FianzaFormView(idContrato: id, actual: modelo.fianza ?? nil, rentaMensual: renta) { modelo.fianza = .some($0) }
                        case .devolver:
                            if let f = modelo.fianza ?? nil {
                                DevolucionFianzaView(fianza: f) { modelo.fianza = .some($0) }
                            }
                        }
                    }
                }
            }
            .alertaError($modelo.error)
    }
}

/// Alta o edición: importe, cuándo la entregó el inquilino y dónde se depositó.
struct FianzaFormView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let idContrato: Int
    let actual: Fianza?
    let rentaMensual: Decimal
    let alGuardar: (Fianza) -> Void

    @State private var importe: Decimal?
    @State private var cobrada = true
    @State private var fechaCobro = Date.now
    @State private var depositada = false
    @State private var fechaDeposito = Date.now
    @State private var organismo = ""
    @State private var referencia = ""
    @State private var notas = ""
    @State private var guardando = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("Importe", value: $importe, format: .currency(code: "EUR").locale(Formato.locale))
                    .keyboardType(.decimalPad)
                    .disabled(actual?.fechaDevolucion != nil)
                    .accessibilityIdentifier("campoImporteFianza")
                Toggle("Entregada por el inquilino", isOn: $cobrada)
                if cobrada { DatePicker("Fecha de entrega", selection: $fechaCobro, in: ...Date.now, displayedComponents: .date) }
            } footer: {
                Text(actual?.fechaDevolucion != nil ? "Ya está devuelta: el importe no se puede cambiar."
                                                     : "Lo habitual es una mensualidad (\(Formato.euros(rentaMensual))).")
            }
            .filaLista()
            Section {
                Toggle("Depositada", isOn: $depositada)
                    .accessibilityIdentifier("interruptorDepositada")
                if depositada {
                    DatePicker("Fecha de depósito", selection: $fechaDeposito, in: (cobrada ? fechaCobro : .distantPast)...,
                               displayedComponents: .date)
                    TextField("Organismo", text: $organismo, prompt: Text("Organismo de tu comunidad autónoma"))
                    TextField("Referencia", text: $referencia)
                }
            } header: {
                Text("Depósito")
            } footer: {
                Text("En muchas comunidades autónomas la fianza se deposita en un organismo público. Comprueba el plazo y el organismo de la tuya.")
            }
            .filaLista()
            Section("Notas") {
                TextField("Notas", text: $notas, axis: .vertical).lineLimit(2...5)
            }
            .filaLista()
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                .filaLista()
            }
        }
        .estiloLista()
        .navigationTitle(actual == nil ? "Nueva fianza" : "Editar fianza")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
            ToolbarItem(placement: .confirmationAction) {
                if guardando { ProgressView() } else {
                    Button("Guardar") { Task { await guardar() } }.disabled((importe ?? 0) <= 0)
                }
            }
        }
        .onAppear {
            guard let f = actual else { importe = rentaMensual; return }
            importe = f.importe
            cobrada = f.fechaCobro != nil
            fechaCobro = f.fechaCobro ?? .now
            depositada = f.fechaDeposito != nil
            fechaDeposito = f.fechaDeposito ?? .now
            organismo = f.organismoDeposito ?? ""
            referencia = f.referenciaDeposito ?? ""
            notas = f.notas ?? ""
        }
    }

    private func guardar() async {
        guard let importe else { return }
        guardando = true
        defer { guardando = false }
        let req = FianzaRequest(importe: importe,
                                fechaCobro: cobrada ? FechaAPI.texto(fechaCobro) : nil,
                                fechaDeposito: depositada ? FechaAPI.texto(fechaDeposito) : nil,
                                organismoDeposito: depositada ? organismo : nil,
                                referenciaDeposito: depositada ? referencia : nil,
                                notas: notas)
        do {
            alGuardar(try await sesion.api.enviar(.guardarFianza(contrato: idContrato, req)))
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Devolución de la fianza: si se devuelve menos, hay que decir por qué.
struct DevolucionFianzaView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let fianza: Fianza
    let alGuardar: (Fianza) -> Void

    @State private var fecha = Date.now
    @State private var importe: Decimal?
    @State private var motivo = ""
    @State private var guardando = false
    @State private var error: String?

    private var parcial: Bool { (importe ?? 0) < fianza.importe }
    private var valido: Bool {
        guard let importe, importe >= 0, importe <= fianza.importe else { return false }
        return !parcial || !motivo.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Fecha", selection: $fecha, in: (fianza.fechaCobro ?? .distantPast)..., displayedComponents: .date)
                TextField("Importe devuelto", value: $importe, format: .currency(code: "EUR").locale(Formato.locale))
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("campoImporteDevuelto")
            } footer: {
                Text("Fianza de \(Formato.euros(fianza.importe)).")
            }
            .filaLista()
            if parcial {
                Section {
                    TextField("Motivo", text: $motivo, prompt: Text("Daños, recibos pendientes…"), axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("campoMotivo")
                } header: {
                    Text("Se retienen \(Formato.euros(fianza.importe - (importe ?? 0)))")
                } footer: {
                    Text("Obligatorio si no se devuelve entera.")
                }
                .filaLista()
            }
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                .filaLista()
            }
        }
        .estiloLista()
        .navigationTitle("Devolver fianza")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
            ToolbarItem(placement: .confirmationAction) {
                if guardando { ProgressView() } else {
                    Button("Guardar") { Task { await guardar() } }.disabled(!valido)
                }
            }
        }
        .onAppear { importe = fianza.importe }
    }

    private func guardar() async {
        guard let importe else { return }
        guardando = true
        defer { guardando = false }
        let req = DevolucionFianzaRequest(fechaDevolucion: FechaAPI.texto(fecha), importeDevuelto: importe,
                                          motivoRetencion: parcial ? motivo : nil)
        do {
            alGuardar(try await sesion.api.enviar(.devolverFianza(contrato: fianza.idContrato, req)))
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
