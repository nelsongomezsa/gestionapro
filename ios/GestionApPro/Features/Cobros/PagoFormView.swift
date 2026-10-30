import SwiftUI

/// Registrar un pago de un contrato activo (como en el escritorio).
struct PagoFormView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    var idContrato: Int?
    var importe: Decimal?
    let alGuardar: (Pago) -> Void

    @State private var contratos: [Contrato] = []
    @State private var seleccion: Int?
    @State private var cantidad = 0.0
    @State private var metodo: MetodoPago = .transferencia
    @State private var fecha = Date.now
    @State private var guardando = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Contrato") {
                    Picker("Contrato activo", selection: $seleccion) {
                        Text("Elige un contrato").tag(Int?.none)
                        ForEach(contratos) { c in
                            Text("\(c.inquilino.nombre) · Hab. \(c.habitacion.numero)").tag(Int?.some(c.id))
                        }
                    }
                }
                Section("Pago") {
                    CampoNumerico("Importe", valor: $cantidad, sufijo: "€")
                    Picker("Método", selection: $metodo) {
                        ForEach(MetodoPago.allCases) { Text($0.nombre).tag($0) }
                    }
                    DatePicker("Fecha", selection: $fecha, in: ...Date.now, displayedComponents: .date)
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                }
            }
            .environment(\.locale, Formato.locale)
            .navigationTitle("Registrar pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if guardando { ProgressView() } else {
                        Button("Guardar") { Task { await guardar() } }.disabled(seleccion == nil || cantidad <= 0)
                    }
                }
            }
            .task { await cargarContratos() }
            .onChange(of: seleccion) {
                if importe == nil, let c = contratos.first(where: { $0.id == seleccion }) { cantidad = c.precioMensual.double }
            }
        }
    }

    private func cargarContratos() async {
        do {
            contratos = try await sesion.api.enviar(.contratos(filtro: .activos))
                .sorted { $0.inquilino.nombre.localizedStandardCompare($1.inquilino.nombre) == .orderedAscending }
            seleccion = idContrato
            if let importe { cantidad = importe.double }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func guardar() async {
        guard let seleccion else { return }
        guardando = true
        defer { guardando = false }
        let req = PagoRequest(idContrato: seleccion, cantidad: Decimal(string: String(format: "%.2f", cantidad)) ?? 0,
                              metodoPago: metodo, fechaPago: FechaAPI.texto(fecha))
        do {
            let p = try await sesion.api.enviar(.registrarPago(req))
            alGuardar(p)
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
