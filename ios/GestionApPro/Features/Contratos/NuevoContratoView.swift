import SwiftUI

/// Nuevo contrato. Solo ofrece habitaciones disponibles: la API las reserva en la misma
/// transacción (si otro usuario la alquila a la vez, avisa en vez de duplicar).
struct NuevoContratoView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    var inquilinoInicial: Int? = nil
    let alGuardar: (Contrato) -> Void

    @State private var pisos: [Piso] = []
    @State private var habitaciones: [Habitacion] = []
    @State private var inquilinos: [Inquilino] = []
    @State private var idPiso: Int?
    @State private var idHabitacion: Int?
    @State private var idInquilino: Int?
    @State private var inicio = Date.now
    @State private var fin = Calendar.current.date(byAdding: .year, value: 1, to: .now)!
    @State private var precio = 0.0
    @State private var cargando = true
    @State private var guardando = false
    @State private var error: String?

    private var puedeGuardar: Bool {
        idHabitacion != nil && idInquilino != nil && precio > 0 && fin > inicio
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habitación") {
                    Picker("Piso", selection: $idPiso) {
                        Text("Elige un piso").tag(Int?.none)
                        ForEach(pisos) { Text($0.direccion).tag(Int?.some($0.id)) }
                    }
                    Picker("Habitación", selection: $idHabitacion) {
                        Text(habitaciones.isEmpty && idPiso != nil ? "Sin habitaciones disponibles" : "Elige una habitación").tag(Int?.none)
                        ForEach(habitaciones) { h in
                            Text("Hab. \(h.numero) · \(Formato.euros(h.precio))").tag(Int?.some(h.id))
                        }
                    }
                    .disabled(idPiso == nil || habitaciones.isEmpty)
                }
                .filaLista()
                Section("Inquilino") {
                    Picker("Inquilino", selection: $idInquilino) {
                        Text("Elige un inquilino").tag(Int?.none)
                        ForEach(inquilinos) { Text($0.nombreCompleto).tag(Int?.some($0.id)) }
                    }
                }
                .filaLista()
                Section("Condiciones") {
                    DatePicker("Inicio", selection: $inicio, displayedComponents: .date)
                    DatePicker("Fin", selection: $fin, in: inicio..., displayedComponents: .date)
                    CampoNumerico("Renta mensual", valor: $precio, sufijo: "€")
                }
                .filaLista()
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                    .filaLista()
                }
            }
            .estiloLista()
            .environment(\.locale, Formato.locale)
            .overlay { if cargando { ProgressView() } }
            .navigationTitle("Nuevo contrato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if guardando { ProgressView() } else {
                        Button("Crear") { Task { await guardar() } }.disabled(!puedeGuardar)
                    }
                }
            }
            .task { await cargarListas() }
            .onChange(of: idPiso) { Task { await cargarHabitaciones() } }
            .onChange(of: idHabitacion) {
                if let h = habitaciones.first(where: { $0.id == idHabitacion }) { precio = h.precio.double }
            }
        }
    }

    private func cargarListas() async {
        defer { cargando = false }
        do {
            async let p = sesion.api.enviar(.pisos)
            async let i = sesion.api.enviar(.inquilinos)
            pisos = try await p
            inquilinos = try await i
            idInquilino = inquilinoInicial
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func cargarHabitaciones() async {
        idHabitacion = nil
        habitaciones = []
        guard let idPiso else { return }
        do {
            habitaciones = try await sesion.api.enviar(.habitaciones(piso: idPiso, estado: .disponible))
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func guardar() async {
        guard let idHabitacion, let idInquilino else { return }
        guardando = true
        defer { guardando = false }
        let req = ContratoRequest(idHabitacion: idHabitacion, idInquilino: idInquilino,
                                  fechaInicio: FechaAPI.texto(inicio), fechaFin: FechaAPI.texto(fin),
                                  precioMensual: Decimal(string: String(format: "%.2f", precio)) ?? 0)
        do {
            let c = try await sesion.api.enviar(.crearContrato(req))
            alGuardar(c)
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
