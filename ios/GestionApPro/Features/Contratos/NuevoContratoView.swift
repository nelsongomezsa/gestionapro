import SwiftUI

/// Nuevo contrato. Solo ofrece unidades disponibles: la API las reserva en la misma
/// transacción (si otro usuario la alquila a la vez, avisa en vez de duplicar).
/// En plazas y trasteros: duración libre (atajos de 1 a 12 meses), fianza opcional e IVA opcional.
struct NuevoContratoView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    var inquilinoInicial: Int? = nil
    /// Habitación ya elegida (desde la ficha de una habitación libre).
    var habitacionInicial: Habitacion? = nil
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
    @State private var aplicaIva = false
    @State private var ivaPct = 21.0
    @State private var conFianza = false
    @State private var fianza = 0.0
    @State private var cargando = true
    @State private var guardando = false
    @State private var error: String?

    private var puedeGuardar: Bool {
        idHabitacion != nil && idInquilino != nil && precio > 0 && fin > inicio
            && (!aplicaIva || (ivaPct > 0 && ivaPct <= 30)) && (!conFianza || fianza > 0)
    }

    /// Tipo de lo que se alquila: el de la unidad elegida o, si aún no hay, el del inmueble.
    private var unidad: TipoUnidad {
        habitaciones.first { $0.id == idHabitacion }?.unidad
            ?? pisos.first { $0.id == idPiso }?.tipoInmueble.unidad ?? .habitacion
    }

    /// Base e IVA de la renta (IVA incluido), como en el recibo.
    private var desglose: (base: Double, cuota: Double) {
        let base = (precio / (1 + ivaPct / 100) * 100).rounded() / 100
        return (base, precio - base)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(unidad.nombre) {
                    Picker("Piso", selection: $idPiso) {
                        Text("Elige un piso").tag(Int?.none)
                        ForEach(pisos) { Text($0.direccion).tag(Int?.some($0.id)) }
                    }
                    Picker(unidad.nombre, selection: $idHabitacion) {
                        Text(habitaciones.isEmpty && idPiso != nil ? String(localized: "No hay nada disponible") : unidad.elige).tag(Int?.none)
                        ForEach(habitaciones) { h in
                            Text("\(h.etiqueta) · \(Formato.euros(h.precio))").tag(Int?.some(h.id))
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
                Section {
                    DatePicker("Inicio", selection: $inicio, displayedComponents: .date)
                    DatePicker("Fin", selection: $fin, in: inicio..., displayedComponents: .date)
                    if unidad != .habitacion {
                        // Duración libre: atajos habituales en garajes y trasteros.
                        HStack {
                            ForEach([1, 3, 6, 12], id: \.self) { meses in
                                Button(meses == 12 ? String(localized: "1 año") : String(localized: "\(meses) m")) {
                                    fin = Calendar.current.date(byAdding: .month, value: meses, to: inicio) ?? fin
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel(meses == 12 ? String(localized: "Un año") : String(localized: "\(meses) meses"))
                            }
                        }
                    }
                    CampoNumerico(aplicaIva ? String(localized: "Renta mensual (IVA incluido)") : String(localized: "Renta mensual"),
                                  valor: $precio, sufijo: "€")
                } header: {
                    Text("Condiciones")
                }
                .filaLista()
                if unidad != .habitacion {
                    Section {
                        Toggle("Con fianza", isOn: $conFianza.animation())
                            .accessibilityIdentifier("conFianza")
                        if conFianza {
                            CampoNumerico("Fianza", valor: $fianza, sufijo: "€")
                        }
                    } footer: {
                        Text("Opcional en plazas y trasteros. Puedes registrarla también más tarde desde el contrato.")
                    }
                    .filaLista()
                    Section {
                        Toggle("Aplicar IVA", isOn: $aplicaIva.animation())
                            .accessibilityIdentifier("aplicarIva")
                        if aplicaIva {
                            CampoNumerico("IVA", valor: $ivaPct, sufijo: "%")
                            LabeledContent("Base imponible", value: Formato.euros(Decimal(desglose.base)))
                            LabeledContent("IVA", value: Formato.euros(Decimal(desglose.cuota)))
                        }
                    } footer: {
                        Text(Self.avisoIva)
                    }
                    .filaLista()
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                    .filaLista()
                }
            }
            .estiloLista()
            .environment(\.locale, Formato.localeFechas)
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
                if let h = habitaciones.first(where: { $0.id == idHabitacion }) {
                    precio = h.precio.double
                    if fianza == 0 { fianza = h.precio.double }
                    // Garajes y trasteros: por defecto, un mes (la duración es libre).
                    if h.unidad != .habitacion, habitacionInicial == nil || fin == Calendar.current.date(byAdding: .year, value: 1, to: inicio) {
                        fin = Calendar.current.date(byAdding: .month, value: 1, to: inicio) ?? fin
                    }
                    if h.unidad == .habitacion { aplicaIva = false; conFianza = false }
                }
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
            idPiso = habitacionInicial?.piso.id
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
            if let h = habitacionInicial, h.piso.id == idPiso, habitaciones.contains(where: { $0.id == h.id }) {
                idHabitacion = h.id
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func guardar() async {
        guard let idHabitacion, let idInquilino else { return }
        guardando = true
        defer { guardando = false }
        let conIva = aplicaIva && unidad != .habitacion
        let req = ContratoRequest(idHabitacion: idHabitacion, idInquilino: idInquilino,
                                  fechaInicio: FechaAPI.texto(inicio), fechaFin: FechaAPI.texto(fin),
                                  precioMensual: Decimal(string: String(format: "%.2f", precio)) ?? 0,
                                  aplicaIva: conIva ? true : nil,
                                  ivaPct: conIva ? Decimal(string: String(format: "%.2f", ivaPct)) : nil)
        do {
            let c = try await sesion.api.enviar(.crearContrato(req))
            if conFianza, unidad != .habitacion, fianza > 0 {
                // La fianza va aparte (como siempre); si falla, el contrato ya está creado y se puede añadir después.
                _ = try? await sesion.api.enviar(.guardarFianza(contrato: c.id, FianzaRequest(
                    importe: Decimal(string: String(format: "%.2f", fianza)) ?? 0, fechaCobro: FechaAPI.texto(inicio),
                    fechaDeposito: nil, organismoDeposito: nil, referenciaDeposito: nil, notas: nil)))
            }
            alGuardar(c)
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Informativo, sin consejo fiscal.
    static let avisoIva = String(localized: "Desactivado por defecto. Si lo activas, la renta incluye el IVA y el recibo lo desglosa. Si no sabes si debes aplicarlo, confírmalo con tu asesor.")
}
