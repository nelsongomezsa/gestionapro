import Charts
import SwiftUI

struct PisoDetalleView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var piso: Piso
    @State private var ingresos: [ImporteMes] = []
    @State private var contratos: [Contrato] = []
    @State private var pagos: [Pago] = []
    @State private var incidencias: [Incidencia] = []
    @State private var editando = false
    @State private var documento: DocumentoPDF?
    @State private var generandoPDF = false
    @State private var error: String?

    init(piso: Piso) {
        _piso = State(initialValue: piso)
    }

    private let columnas = [GridItem(.flexible(), spacing: Tema.Espacio.s), GridItem(.flexible(), spacing: Tema.Espacio.s)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                cabecera

                if let m = piso.metricas {
                    LazyVGrid(columns: columnas, spacing: Tema.Espacio.s) {
                        TarjetaKPI(titulo: "Cash flow mensual", valor: Formato.euros(m.cashFlowMensual),
                                   icono: "arrow.left.arrow.right", tono: Tono.signo(m.cashFlowMensual))
                        TarjetaKPI(titulo: "Rentabilidad bruta", valor: Formato.porcentaje(m.rentabilidadBrutaPct),
                                   icono: "percent", tono: (m.calificacion as Calificacion?).tono)
                        TarjetaKPI(titulo: "Rentabilidad neta", valor: Formato.porcentaje(m.rentabilidadNetaPct),
                                   icono: "chart.line.uptrend.xyaxis", tono: Tono.signo(m.rentabilidadNetaPct),
                                   detalle: "Antes de financiación")
                        TarjetaKPI(titulo: "Cash-on-cash", valor: Formato.porcentaje(m.cashOnCashPct),
                                   icono: "banknote", tono: Tono.signo(m.cashOnCashPct),
                                   detalle: "Cash flow anual / capital propio")
                    }
                }

                seccion("Ingresos últimos 12 meses") {
                    if ingresos.isEmpty {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                    } else {
                        GraficoIngresos(meses: ingresos).frame(height: 170)
                    }
                }

                if let m = piso.metricas {
                    seccion("Flujo de caja") {
                        FilaMetrica(titulo: "Ingresos mensuales", valor: Formato.euros(piso.ingresosMensuales),
                                    nota: "Contratos activos hoy")
                        Divider()
                        FilaMetrica(titulo: "Cuota de hipoteca", valor: Formato.euros(m.cuotaMensualHipoteca))
                        Divider()
                        FilaMetrica(titulo: "Gastos anuales", valor: Formato.euros(m.gastosAnuales))
                        Divider()
                        FilaMetrica(titulo: "Cash flow mensual", valor: Formato.euros(m.cashFlowMensual),
                                    tono: Tono.signo(m.cashFlowMensual))
                    }
                    seccion("Inversión") {
                        FilaMetrica(titulo: "Inversión total", valor: Formato.euros(m.inversionTotal))
                        Divider()
                        FilaMetrica(titulo: "Capital propio", valor: Formato.euros(m.capitalPropio))
                        Divider()
                        FilaMetrica(titulo: "Plusvalía latente", valor: Formato.euros(m.plusvaliaLatente),
                                    tono: Tono.signo(m.plusvaliaLatente))
                        Divider()
                        FilaMetrica(titulo: "PER inmobiliario", valor: Formato.anios(m.perAnios),
                                    nota: "Años de alquiler para pagar la inversión")
                    }
                } else {
                    EstadoVacio(icono: "chart.bar.xaxis", titulo: "Sin datos financieros",
                                mensaje: "Añade los datos de compra y gastos para ver las métricas.",
                                accionTitulo: "Añadir datos") { editando = true }
                        .tarjeta()
                }

                seccion("Gestión") {
                    NavigationLink(value: DestinoPiso.habitaciones(piso.breve)) {
                        FilaMetrica(titulo: "Habitaciones", valor: "\(piso.ocupacion.total)", icono: "bed.double")
                    }
                    .accessibilityIdentifier("enlaceHabitaciones")
                    Divider()
                    NavigationLink(value: DestinoPiso.mapa(piso.breve)) {
                        FilaMetrica(titulo: "Ver en el mapa", valor: piso.ciudad.nombre, icono: "map")
                    }
                    .accessibilityIdentifier("enlaceMapa")
                    Divider()
                    Button { editando = true } label: {
                        FilaMetrica(titulo: "Editar datos financieros", valor: "", icono: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("editarDatosFinancieros")
                }
                .buttonStyle(.plain)

                seccion("Contratos activos (\(contratos.count))") {
                    if contratos.isEmpty { Text("Sin contratos activos").foregroundStyle(Tema.Color.textoSecundario) }
                    ForEach(contratos) { c in
                        NavigationLink(value: DestinoPiso.contrato(c.id)) { FilaContratoCompleto(contrato: c).contentShape(.rect) }
                            .buttonStyle(.plain)
                        if c != contratos.last { Divider() }
                    }
                }

                seccion("Últimos pagos") {
                    if pagos.isEmpty { Text("Sin pagos registrados").foregroundStyle(Tema.Color.textoSecundario) }
                    ForEach(pagos.prefix(5)) { p in
                        FilaPago(pago: p)
                        if p != pagos.prefix(5).last { Divider() }
                    }
                }

                seccion("Incidencias abiertas (\(incidencias.count))") {
                    if incidencias.isEmpty {
                        Label("Sin incidencias abiertas", systemImage: "checkmark.seal").foregroundStyle(Tema.Color.positivo)
                    }
                    ForEach(incidencias) { i in
                        NavigationLink(value: DestinoPiso.incidencia(i.id)) { FilaIncidencia(incidencia: i).contentShape(.rect) }
                            .buttonStyle(.plain)
                        if i != incidencias.last { Divider() }
                    }
                }

                seccion("Ocupación") {
                    FilaMetrica(titulo: "Habitaciones", valor: "\(piso.ocupacion.total)", icono: "bed.double")
                    Divider()
                    FilaMetrica(titulo: "Alquiladas", valor: "\(piso.ocupacion.alquiladas)", tono: .positivo, icono: "key")
                    Divider()
                    FilaMetrica(titulo: "Disponibles", valor: "\(piso.ocupacion.disponibles)", icono: "door.left.hand.open")
                    Divider()
                    FilaMetrica(titulo: "En mantenimiento", valor: "\(piso.ocupacion.mantenimiento)",
                                tono: piso.ocupacion.mantenimiento > 0 ? .aviso : nil, icono: "wrench")
                }

                if let notas = piso.datosFinancieros?.notas, !notas.isEmpty {
                    seccion("Notas") { Text(notas).font(Tema.Fuente.detalle) }
                }
            }
            .padding(Tema.Espacio.m)
        }
        .background(Tema.Color.fondo)
        .navigationTitle("Piso")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await exportar() } } label: {
                    if generandoPDF { ProgressView() } else { Label("Exportar PDF", systemImage: "doc.richtext") }
                }
                .disabled(generandoPDF)
            }
        }
        .task { await cargarExtras() }
        .refreshable { await recargar() }
        .sheet(isPresented: $editando) {
            DatosFinancierosFormView(piso: piso) { piso = $0 }
        }
        .visorPDF($documento)
        .alertaError($error)
    }

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            (piso.metricas?.calificacion).insignia
            Text(piso.direccion)
                .font(Tema.Fuente.titulo)
                .fixedSize(horizontal: false, vertical: true)
            Label(piso.ciudad.nombre, systemImage: "mappin.and.ellipse")
                .foregroundStyle(Tema.Color.textoSecundario)
        }
    }

    private func cargarExtras() async {
        async let i = sesion.api.enviar(.ingresosPiso(id: piso.id))
        async let c = sesion.api.enviar(.contratos(filtro: .activos, piso: piso.id))
        async let p = sesion.api.enviar(.pagosDePiso(piso.id))
        async let inc = sesion.api.enviar(.incidencias(piso: piso.id))
        ingresos = (try? await i) ?? []
        contratos = (try? await c) ?? []
        pagos = (try? await p) ?? []
        incidencias = ((try? await inc) ?? []).filter { $0.estado != .resuelta }
    }

    private func recargar() async {
        if let nuevo = try? await sesion.api.enviar(.piso(id: piso.id)) { piso = nuevo }
        await cargarExtras()
    }

    private func exportar() async {
        generandoPDF = true
        defer { generandoPDF = false }
        do {
            documento = DocumentoPDF(titulo: "Piso \(piso.direccion)", datos: try await sesion.api.descargar(Rutas.pdfPiso(piso.id)))
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func seccion<Contenido: View>(_ titulo: String, @ViewBuilder contenido: () -> Contenido) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            Text(titulo).estiloEtiqueta().padding(.horizontal, Tema.Espacio.xxs)
            VStack(alignment: .leading, spacing: Tema.Espacio.s) { contenido() }
                .tarjeta()
        }
    }
}

/// Pantallas que se abren desde el detalle de un piso. La pila de Pisos navega por valor
/// (`navigationDestination(for:)`); mezclar ahí enlaces con la vista de destino escrita
/// directamente hacía que algunos no navegaran.
enum DestinoPiso: Hashable {
    case habitaciones(PisoBreve)
    case mapa(PisoBreve)
    case contrato(Int)
    case incidencia(Int)

    @MainActor @ViewBuilder
    var vista: some View {
        switch self {
        case let .habitaciones(piso): HabitacionesView(piso: piso)
        case let .mapa(piso): MapaDireccion(titulo: piso.direccion, direccion: piso.direccion, ciudad: piso.ciudad)
        case let .contrato(id): ContratoDetalleView(id: id)
        case let .incidencia(id): IncidenciaDetalleView(id: id)
        }
    }
}

/// Datos financieros del piso (diálogo "Datos financieros" de Mis Pisos en el escritorio).
struct DatosFinancierosFormView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let piso: Piso
    let alGuardar: (Piso) -> Void

    @State private var d = DatosFinancierosRequest()
    @State private var guardando = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Compra") {
                    campo("Precio de compra", \.precioCompra)
                    campo("ITP pagado", \.itpPagado)
                    campo("Notaría", \.gastosNotaria)
                    campo("Registro", \.gastosRegistro)
                    campo("Reforma", \.costeReforma)
                    campo("Mobiliario", \.costeMobiliario)
                    campo("Otros gastos de compra", \.otrosGastosCompra)
                }
                Section {
                    Toggle("Tiene hipoteca", isOn: $d.tieneHipoteca)
                    if d.tieneHipoteca {
                        campo("Importe", \.importeHipoteca)
                        campo("Tipo de interés", \.tipoInteres, sufijo: "%")
                        Stepper(value: $d.plazoAnos, in: 0...50) { LabeledContent("Plazo", value: "\(d.plazoAnos) años") }
                    }
                } header: {
                    Text("Hipoteca")
                } footer: {
                    Text("La cuota se calcula con amortización francesa, como en el escritorio.")
                }
                Section("Gastos") {
                    campo("IBI anual", \.gastoIbiAnual)
                    campo("Comunidad (al mes)", \.gastoComunidadMensual)
                    campo("Seguro anual", \.gastoSeguroAnual)
                    campo("Mantenimiento anual", \.gastoMantenimientoAnual)
                }
                Section("Valor") { campo("Valor de mercado actual", \.valorMercadoActual) }
                Section("Notas") {
                    TextField("Notas", text: Binding(get: { d.notas ?? "" }, set: { d.notas = $0.isEmpty ? nil : $0 }), axis: .vertical)
                        .lineLimit(3...8)
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                }
            }
            .navigationTitle("Datos financieros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    if guardando { ProgressView() } else { Button("Guardar") { Task { await guardar() } } }
                }
            }
            .onAppear { d = DatosFinancierosRequest(piso.datosFinancieros) }
        }
    }

    private func campo(_ titulo: String, _ ruta: WritableKeyPath<DatosFinancierosRequest, Decimal>, sufijo: String = "€") -> some View {
        CampoNumerico(titulo, valor: Binding(get: { d[keyPath: ruta].double },
                                             set: { d[keyPath: ruta] = Decimal(string: String(format: "%.2f", $0)) ?? 0 }),
                      sufijo: sufijo)
    }

    private func guardar() async {
        guardando = true
        defer { guardando = false }
        let req = PisoRequest(direccion: piso.direccion, numeroHabitaciones: piso.numeroHabitaciones,
                              idCiudad: piso.ciudad.id, datosFinancieros: d)
        do {
            alGuardar(try await sesion.api.enviar(.actualizarPiso(id: piso.id, req)))
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
