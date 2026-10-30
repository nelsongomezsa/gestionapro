import Charts
import SwiftUI

struct PisoDetalleView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var piso: Piso
    @State private var ingresos: [ImporteMes] = []
    /// nil mientras carga; así una respuesta vacía o un fallo no se quedan "cargando" para siempre.
    @State private var ingresosCargados: Bool?
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                cabecera

                if let m = piso.metricas {
                    TarjetaHero(titulo: "Cash flow previsto al mes", valor: Formato.euros(m.cashFlowMensual),
                                accesorio: AnyView((m.calificacion as Calificacion?).insignia)) {
                        ParDatos {
                            DatoCompacto(titulo: "Ingresos previstos", valor: Formato.euros(piso.ingresosMensuales))
                        } derecha: {
                            DatoCompacto(titulo: "Hipoteca y gastos al mes",
                                         valor: Formato.euros(m.cuotaMensualHipoteca + m.gastosAnuales / 12))
                        }
                        BotonSecundario(titulo: "Editar datos financieros", icono: "slider.horizontal.3") { editando = true }
                            .accessibilityIdentifier("editarDatosFinancieros")
                    }

                    Grid(horizontalSpacing: Tema.Espacio.s, verticalSpacing: Tema.Espacio.s) {
                        GridRow {
                            TarjetaKPI(titulo: "Rentabilidad bruta", valor: Formato.porcentaje(m.rentabilidadBrutaPct),
                                       icono: "percent", tono: (m.calificacion as Calificacion?).tono, detalle: "Alquiler / inversión")
                            TarjetaKPI(titulo: "Rentabilidad neta", valor: Formato.porcentaje(m.rentabilidadNetaPct),
                                       icono: "chart.line.uptrend.xyaxis", tono: Tono.signo(m.rentabilidadNetaPct),
                                       detalle: "Antes de financiación")
                        }
                        GridRow {
                            TarjetaKPI(titulo: "Cash-on-cash", valor: Formato.porcentaje(m.cashOnCashPct),
                                       icono: "banknote", tono: Tono.signo(m.cashOnCashPct),
                                       detalle: "Sobre el capital propio")
                            TarjetaKPI(titulo: "PER inmobiliario", valor: Formato.anios(m.perAnios),
                                       icono: "hourglass", tono: .primario, detalle: "Años para recuperarla")
                        }
                    }
                } else {
                    EstadoVacio(icono: "chart.bar.xaxis", titulo: "Sin datos financieros",
                                mensaje: "Añade los datos de compra y gastos para ver las métricas.",
                                accionTitulo: "Añadir datos") { editando = true }
                        .tarjeta()
                }

                SeccionTarjeta(titulo: "Ingresos cobrados · 12 meses") {
                    if ingresosCargados == nil {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                    } else if ingresosCargados == false {
                        Text("No se pudieron cargar los ingresos. Desliza hacia abajo para reintentar.")
                            .font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                    } else {
                        GraficoIngresos(meses: ingresos).frame(height: 220)
                    }
                }

                if let m = piso.metricas {
                    // Desglose del cash flow de la tarjeta principal (sin repetir el total).
                    SeccionTarjeta(titulo: "Cómo se calcula") {
                        FilaMetrica(titulo: "Ingresos previstos", valor: Formato.euros(piso.ingresosMensuales),
                                    nota: "Rentas de los contratos activos hoy", tono: .positivo)
                        Divider().overlay(Tema.Color.borde)
                        FilaMetrica(titulo: "Cuota de hipoteca", valor: "− " + Formato.euros(m.cuotaMensualHipoteca))
                        Divider().overlay(Tema.Color.borde)
                        FilaMetrica(titulo: "Gastos", valor: "− " + Formato.euros(m.gastosAnuales / 12),
                                    nota: "\(Formato.euros(m.gastosAnuales)) al año, repartidos por mes")
                    }
                    SeccionTarjeta(titulo: "Inversión") {
                        FilaMetrica(titulo: "Inversión total", valor: Formato.euros(m.inversionTotal))
                        Divider().overlay(Tema.Color.borde)
                        FilaMetrica(titulo: "Capital propio", valor: Formato.euros(m.capitalPropio))
                        Divider().overlay(Tema.Color.borde)
                        FilaMetrica(titulo: "Plusvalía latente", valor: Formato.euros(m.plusvaliaLatente),
                                    nota: "Valor actual frente al precio de compra", tono: Tono.signo(m.plusvaliaLatente))
                    }
                }

                SeccionTarjeta(titulo: "Habitaciones") {
                    let o = piso.ocupacion
                    VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                        BarraProgreso(valor: o.total > 0 ? Double(o.alquiladas) / Double(o.total) : 0,
                                      tono: Tono.ocupacion(o.total > 0 ? Double(o.alquiladas) * 100 / Double(o.total) : 0))
                        Text("\(o.alquiladas) de \(o.total) alquiladas")
                            .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    }
                    ParDatos {
                        DatoCompacto(titulo: "Disponibles", valor: "\(o.disponibles)")
                    } derecha: {
                        DatoCompacto(titulo: "En mantenimiento", valor: "\(o.mantenimiento)",
                                     tono: o.mantenimiento > 0 ? .aviso : nil)
                    }
                    Divider().overlay(Tema.Color.borde)
                    NavigationLink(value: DestinoPiso.habitaciones(piso.breve)) {
                        FilaMetrica(titulo: "Gestionar habitaciones", valor: "", icono: "bed.double")
                    }
                    .accessibilityIdentifier("enlaceHabitaciones")
                    Divider().overlay(Tema.Color.borde)
                    NavigationLink(value: DestinoPiso.mapa(piso.breve)) {
                        FilaMetrica(titulo: "Ver en el mapa", valor: "", icono: "map")
                    }
                    .accessibilityIdentifier("enlaceMapa")
                }
                .buttonStyle(.plain)

                SeccionTarjeta(titulo: "Contratos activos") {
                    if contratos.isEmpty { Text("Sin contratos activos").foregroundStyle(Tema.Color.textoSecundario) }
                    ForEach(contratos) { c in
                        NavigationLink(value: DestinoPiso.contrato(c.id)) { FilaContratoCompleto(contrato: c, mostrarPiso: false).contentShape(.rect) }
                            .buttonStyle(.plain)
                        if c != contratos.last { Divider().overlay(Tema.Color.borde) }
                    }
                }

                SeccionTarjeta(titulo: "Últimos pagos") {
                    if pagos.isEmpty { Text("Sin pagos registrados").foregroundStyle(Tema.Color.textoSecundario) }
                    ForEach(pagos.prefix(5)) { p in
                        FilaPago(pago: p)
                        if p != pagos.prefix(5).last { Divider().overlay(Tema.Color.borde) }
                    }
                }

                SeccionTarjeta(titulo: "Incidencias abiertas") {
                    if incidencias.isEmpty {
                        HStack(spacing: Tema.Espacio.s) {
                            IconoEtiqueta(icono: "checkmark.seal", tono: .positivo)
                            Text("Sin incidencias abiertas").foregroundStyle(Tema.Color.textoSecundario)
                        }
                    }
                    ForEach(incidencias) { i in
                        NavigationLink(value: DestinoPiso.incidencia(i.id)) { FilaIncidencia(incidencia: i, mostrarPiso: false).contentShape(.rect) }
                            .buttonStyle(.plain)
                        if i != incidencias.last { Divider().overlay(Tema.Color.borde) }
                    }
                }

                if let notas = piso.datosFinancieros?.notas, !notas.isEmpty {
                    SeccionTarjeta(titulo: "Notas") { Text(notas).font(Tema.Fuente.detalle) }
                }
            }
            .padding(.horizontal, Tema.Espacio.m)
            .padding(.bottom, Tema.Espacio.l)
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
        VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
            Text(piso.direccion)
                .font(Tema.Fuente.titulo)
                .foregroundStyle(Tema.Color.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Label(piso.ciudad.nombre, systemImage: "mappin.and.ellipse")
                .font(Tema.Fuente.detalle)
                .foregroundStyle(Tema.Color.textoSecundario)
        }
        .padding(.top, Tema.Espacio.xs)
    }

    private func cargarExtras() async {
        async let i = sesion.api.enviar(.ingresosPiso(id: piso.id))
        async let c = sesion.api.enviar(.contratos(filtro: .activos, piso: piso.id))
        async let p = sesion.api.enviar(.pagosDePiso(piso.id))
        async let inc = sesion.api.enviar(.incidencias(piso: piso.id))
        if let lista = try? await i {
            ingresos = lista
            ingresosCargados = true
        } else {
            ingresosCargados = false
        }
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
                Group {
                Section("Compra") {
                    campo("Precio de compra", \.precioCompra)
                    campo("ITP pagado", \.itpPagado)
                    campo("Notaría", \.gastosNotaria)
                    campo("Registro", \.gastosRegistro)
                    campo("Reforma", \.costeReforma)
                    campo("Mobiliario", \.costeMobiliario)
                    campo("Otros gastos", \.otrosGastosCompra)
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
                .filaLista()
            }
            .estiloLista()
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
