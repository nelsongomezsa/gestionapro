import SwiftUI

/// Nuevo piso en tres pasos: datos básicos, habitaciones con precio (se crean solas según el número)
/// y datos financieros (opcional, se pueden completar después). Al terminar se abre el piso creado.
struct NuevoPisoView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    let alCrear: (Piso) -> Void

    @State private var vm = NuevoPisoViewModel()
    /// Los errores de un paso se muestran al escribir en el campo o al intentar avanzar.
    @State private var intentado: Set<NuevoPisoViewModel.Paso> = []
    @State private var precioComun = 0.0
    @FocusState private var enfocado: Campo?

    private enum Campo: Hashable { case direccion, ciudad }

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            Form {
                Section {
                    IndicadorPasos(paso: vm.paso)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                switch vm.paso {
                case .basicos: pasoBasicos
                case .habitaciones: pasoHabitaciones
                case .financieros: pasoFinancieros
                }
                if let error = vm.error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                        .filaLista()
                }
            }
            .estiloLista()
            .environment(\.locale, Formato.localeFechas)
            .navigationTitle("Nuevo piso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if vm.paso == .basicos {
                        Button("Cancelar") { cerrar() }
                    } else {
                        Button("Atrás", systemImage: "chevron.left") { ir(-1) }
                            .accessibilityIdentifier("pisoAtras")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.guardando {
                        ProgressView()
                    } else if vm.paso == .financieros {
                        Button("Crear piso") { Task { await crear() } }
                            .disabled(!vm.puedeGuardar)
                            .accessibilityIdentifier("crearPiso")
                    } else {
                        Button("Siguiente") { siguiente() }
                            .accessibilityIdentifier("pisoSiguiente")
                    }
                }
            }
            .task { await vm.cargarCiudades(con: sesion.api) }
            .interactiveDismissDisabled(!vm.direccion.isEmpty)
        }
    }

    // MARK: Pasos

    @ViewBuilder private var pasoBasicos: some View {
        @Bindable var vm = vm
        let mostrar = intentado.contains(.basicos)
        Section {
            TextField("Calle, número y piso", text: $vm.direccion, axis: .vertical)
                .textContentType(.fullStreetAddress)
                .textInputAutocapitalization(.words)
                .focused($enfocado, equals: .direccion)
                .accessibilityIdentifier("campoDireccion")
        } header: {
            Text("Dirección")
        } footer: {
            if let e = vm.errorDireccion, mostrar || !vm.direccion.isEmpty { ErrorCampo(texto: e) }
        }
        .filaLista()

        Section {
            if !vm.otraCiudad {
                Picker("Ciudad", selection: $vm.idCiudad) {
                    Text("Elige una").tag(Int?.none)
                    ForEach(vm.ciudades) { Text($0.nombre).tag(Int?.some($0.id)) }
                }
                .accessibilityIdentifier("campoCiudad")
            }
            Toggle("Otra ciudad", isOn: $vm.otraCiudad.animation(reducirMovimiento ? nil : Tema.Movimiento.suave))
                .tint(Tema.Color.primario)
            if vm.otraCiudad {
                TextField("Nombre de la ciudad", text: $vm.nuevaCiudad)
                    .textContentType(.addressCity)
                    .textInputAutocapitalization(.words)
                    .focused($enfocado, equals: .ciudad)
                    .accessibilityIdentifier("campoNuevaCiudad")
            }
        } header: {
            Text("Ciudad")
        } footer: {
            if let e = vm.errorCiudad, mostrar || !vm.nuevaCiudad.isEmpty { ErrorCampo(texto: e) }
        }
        .filaLista()

        Section {
            Stepper(value: Binding(get: { vm.numeroHabitaciones }, set: { vm.cambiarNumero($0) }),
                    in: 1...NuevoPisoViewModel.maxHabitaciones) {
                LabeledContent("Habitaciones", value: "\(vm.numeroHabitaciones)")
                    .monospacedDigit()
            }
            .accessibilityIdentifier("numeroHabitaciones")
        } footer: {
            Text("En el siguiente paso se crean solas, con su precio.")
        }
        .filaLista()
    }

    @ViewBuilder private var pasoHabitaciones: some View {
        let mostrar = intentado.contains(.habitaciones)
        Section {
            CampoNumerico("Precio para todas", valor: $precioComun, sufijo: "€")
            Button("Aplicar a todas", systemImage: "square.stack.3d.down.right") {
                vm.aplicarATodas(precioComun)
                Haptica.ligera()
            }
            .disabled(precioComun <= 0)
            .accessibilityIdentifier("aplicarPrecio")
        } footer: {
            Text("Precio mensual de cada habitación. Puedes cambiar cualquiera abajo.")
        }
        .filaLista()

        Section {
            ForEach(vm.habitaciones) { h in
                FilaHabitacionNueva(habitacion: h,
                                    errorNumero: vm.errorNumero(h),
                                    errorPrecio: mostrar || h.precio != 0 ? vm.errorPrecio(h) : nil,
                                    cambiarNumero: { vm.cambiarNumeroHabitacion(h.id, $0) },
                                    cambiarPrecio: { vm.cambiarPrecio(h.id, $0) })
            }
        } header: {
            Text("\(vm.habitaciones.count) habitaciones")
        } footer: {
            Text("Se crean disponibles; después podrás editarlas, alquilarlas o pasarlas a mantenimiento.")
        }
        .filaLista()
    }

    @ViewBuilder private var pasoFinancieros: some View {
        @Bindable var vm = vm
        Section {
            Toggle("Añadir datos financieros ahora", isOn: $vm.conDatosFinancieros.animation(reducirMovimiento ? nil : Tema.Movimiento.suave))
                .tint(Tema.Color.primario)
                .accessibilityIdentifier("conDatosFinancieros")
        } footer: {
            Text("Son opcionales: con ellos se calculan la rentabilidad y el cash flow. Puedes completarlos después desde el piso.")
        }
        .filaLista()
        if vm.conDatosFinancieros {
            SeccionesDatosFinancieros(d: $vm.datos)
        }
        Section("Resumen") {
            LabeledContent("Dirección", value: vm.direccion.trimmingCharacters(in: .whitespacesAndNewlines))
            LabeledContent("Ciudad", value: vm.otraCiudad ? vm.nuevaCiudad : (vm.ciudades.first { $0.id == vm.idCiudad }?.nombre ?? ""))
            LabeledContent("Habitaciones", value: "\(vm.habitaciones.count)")
            LabeledContent("Rentas al mes", value: Formato.euros(vm.habitaciones.reduce(0) { $0 + $1.precio }))
        }
        .filaLista()
    }

    // MARK: Acciones

    private func siguiente() {
        intentado.insert(vm.paso)
        guard vm.puedeAvanzar(desde: vm.paso) else {
            Haptica.error()
            return
        }
        enfocado = nil
        ir(1)
    }

    private func ir(_ delta: Int) {
        guard let nuevo = NuevoPisoViewModel.Paso(rawValue: vm.paso.rawValue + delta) else { return }
        if reducirMovimiento { vm.paso = nuevo } else { withAnimation(Tema.Movimiento.suave) { vm.paso = nuevo } }
    }

    private func crear() async {
        if let piso = await vm.guardar(con: sesion.api) {
            cerrar()
            alCrear(piso)
        }
    }
}

/// "Paso 2 de 3 · Habitaciones" con tres segmentos.
private struct IndicadorPasos: View {
    let paso: NuevoPisoViewModel.Paso

    var body: some View {
        let total = NuevoPisoViewModel.Paso.allCases.count
        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            HStack(spacing: Tema.Espacio.xxs) {
                ForEach(NuevoPisoViewModel.Paso.allCases, id: \.self) { p in
                    Capsule()
                        .fill(p.rawValue <= paso.rawValue ? Tema.Color.primario : Tema.Color.superficieElevada)
                        .frame(height: Tema.Tamano.alturaBarraProgreso)
                }
            }
            Text("Paso \(paso.rawValue + 1) de \(total) · \(paso.titulo)")
                .font(Tema.Fuente.detalle.weight(.semibold))
                .foregroundStyle(Tema.Color.textoSecundario)
        }
        .padding(.horizontal, Tema.Espacio.xxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Paso \(paso.rawValue + 1) de \(total): \(paso.titulo)")
    }
}

/// Fila editable de una habitación nueva: número y precio al mes, con su error debajo.
private struct FilaHabitacionNueva: View {
    let habitacion: NuevoPisoViewModel.HabitacionBorrador
    let errorNumero: String?
    let errorPrecio: String?
    let cambiarNumero: (Int) -> Void
    let cambiarPrecio: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
            HStack(spacing: Tema.Espacio.s) {
                Text("Hab.").foregroundStyle(Tema.Color.textoSecundario)
                TextField("Nº", value: Binding(get: { habitacion.numero }, set: { cambiarNumero($0) }), format: .number)
                    .keyboardType(.numberPad)
                    .frame(width: 48)
                    .monospacedDigit()
                    .accessibilityLabel("Número de la habitación")
                CampoNumerico("Precio", valor: Binding(get: { habitacion.precio }, set: { cambiarPrecio($0) }), sufijo: "€")
                    .accessibilityIdentifier("precioHabitacion")
            }
            if let e = errorNumero ?? errorPrecio { ErrorCampo(texto: e) }
        }
        .padding(.vertical, Tema.Espacio.linea)
    }
}

/// Mensaje de validación bajo un campo.
struct ErrorCampo: View {
    let texto: String

    var body: some View {
        Label(texto, systemImage: "exclamationmark.circle.fill")
            .font(Tema.Fuente.nota)
            .foregroundStyle(Tema.Color.negativo)
            .accessibilityLabel(Text("Error: \(texto)"))
    }
}

/// Editar los datos básicos de un piso (dirección, ciudad y número de habitaciones).
/// Los datos financieros se editan aparte y aquí no se tocan.
struct EditarPisoView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let piso: Piso
    let alGuardar: (Piso) -> Void

    @State private var direccion = ""
    @State private var idCiudad: Int?
    @State private var numero = 1
    @State private var ciudades: [Piso.Ciudad] = []
    @State private var guardando = false
    @State private var error: String?

    private var errorDireccion: String? {
        let t = direccion.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return String(localized: "Escribe la dirección") }
        return t.count > 150 ? String(localized: "Máximo 150 caracteres") : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Calle, número y piso", text: $direccion, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                        .accessibilityIdentifier("campoDireccion")
                } header: {
                    Text("Dirección")
                } footer: {
                    if let e = errorDireccion { ErrorCampo(texto: e) }
                }
                .filaLista()
                Section {
                    Picker("Ciudad", selection: $idCiudad) {
                        ForEach(ciudades) { Text($0.nombre).tag(Int?.some($0.id)) }
                    }
                    Stepper(value: $numero, in: max(1, piso.ocupacion.total)...NuevoPisoViewModel.maxHabitaciones) {
                        LabeledContent("Habitaciones", value: "\(numero)").monospacedDigit()
                    }
                } footer: {
                    Text("Las habitaciones se añaden o quitan desde «Gestionar habitaciones».")
                }
                .filaLista()
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                        .filaLista()
                }
            }
            .estiloLista()
            .navigationTitle("Editar piso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if guardando { ProgressView() } else {
                        Button("Guardar") { Task { await guardar() } }
                            .disabled(errorDireccion != nil || idCiudad == nil)
                            .accessibilityIdentifier("guardarPiso")
                    }
                }
            }
            .task {
                direccion = piso.direccion
                idCiudad = piso.ciudad.id
                numero = piso.numeroHabitaciones
                ciudades = (try? await sesion.api.enviar(.ciudades)) ?? [piso.ciudad]
                if !ciudades.contains(where: { $0.id == piso.ciudad.id }) { ciudades.append(piso.ciudad) }
            }
        }
    }

    private func guardar() async {
        guard let idCiudad else { return }
        guardando = true
        defer { guardando = false }
        // Sin datos financieros: la API conserva los guardados.
        let req = PisoRequest(direccion: direccion.trimmingCharacters(in: .whitespacesAndNewlines),
                              numeroHabitaciones: numero, idCiudad: idCiudad, datosFinancieros: nil)
        do {
            let p = try await sesion.api.enviar(.actualizarPiso(id: piso.id, req))
            Haptica.exito()
            NotificationCenter.default.post(name: .datosCambiados, object: nil)
            alGuardar(p)
            cerrar()
        } catch .noAutorizado {
        } catch {
            Haptica.error()
            self.error = error.localizedDescription
        }
    }
}
