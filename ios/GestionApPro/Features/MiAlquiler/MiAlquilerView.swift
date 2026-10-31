import SwiftUI

/// Pestaña del INQUILINO: su contrato, su habitación y sus pagos (la API solo le devuelve lo suyo).
struct MiAlquilerView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<([Contrato], [Pago])> = .cargando
    @State private var documento: DocumentoPDF?
    @State private var error: String?
    @State private var modeloFianza = ModeloFianza()
    @State private var modeloRenta = ModeloRenta()
    @State private var modeloFirmas = ModeloFirmas()
    @State private var noLeidas = 0
    @State private var verAvisos = false

    var body: some View {
        NavigationStack {
            VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { datos in
                let (contratos, pagos) = datos
                List {
                    if let c = contratos.first(where: \.activo) ?? contratos.first {
                        Section {
                            TarjetaHero(titulo: "Renta mensual", valor: Formato.euros(c.precioMensual),
                                        accesorio: AnyView(InsigniaEstado(texto: c.activo ? c.vencimiento.estadoCorto : "Finalizado",
                                                                          tono: c.activo ? c.vencimiento.tono : .neutro))) {
                                VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
                                    Text("Habitación \(c.habitacion.numero)").font(Tema.Fuente.subtitulo)
                                    Text("\(c.piso.direccion), \(c.piso.ciudad)")
                                        .font(Tema.Fuente.detalle)
                                        .foregroundStyle(Tema.Color.textoSecundario)
                                }
                                ParDatos {
                                    DatoCompacto(titulo: "Inicio", valor: c.fechaInicio.formatted(FormatoFecha.larga))
                                } derecha: {
                                    DatoCompacto(titulo: c.activo ? "Fin" : "Terminó", valor: c.fechaFin.formatted(FormatoFecha.larga))
                                }
                                if c.activo, c.diasRestantes >= 0 {
                                    Text(c.diasRestantes == 1 ? "Queda 1 día de contrato" : "Quedan \(c.diasRestantes) días de contrato")
                                        .font(Tema.Fuente.detalle)
                                        .foregroundStyle(Tema.Color.textoSecundario)
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                        SeccionFirma(modelo: modeloFirmas, idContrato: c.id, partes: [.arrendatario]) { Task { await abrirFirmado(c) } }
                        SeccionRenta(modelo: modeloRenta)
                        SeccionFianza(modelo: modeloFianza, idContrato: c.id)
                        Section {
                            Button { Task { await abrirPDF(c) } } label: {
                                Label("Ver contrato (PDF)", systemImage: "doc.text.magnifyingglass")
                            }
                            NavigationLink {
                                InventariosView(idHabitacion: c.habitacion.id, titulo: "Inventarios")
                            } label: {
                                Label("Inventarios de la habitación", systemImage: "checklist")
                            }
                        }
                        .filaLista()
                        Section {
                            if pagos.isEmpty {
                                Text("Sin pagos registrados").foregroundStyle(Tema.Color.textoSecundario)
                            }
                            ForEach(pagos) { p in
                                Button { Task { await abrirRecibo(p) } } label: {
                                    FilaMetrica(titulo: p.fechaPago.formatted(FormatoFecha.larga), valor: Formato.euros(p.cantidad),
                                                nota: [p.metodoPago.nombre, p.recibo.map { "recibo \($0)" }]
                                                    .compactMap { $0 }.joined(separator: " · "))
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Abre el recibo en PDF")
                            }
                        } header: {
                            Text("Mis pagos")
                        } footer: {
                            if !pagos.isEmpty {
                                Text((pagos.count == 1 ? "1 pago registrado" : "\(pagos.count) pagos registrados")
                                     + ". Toca uno para ver su recibo.")
                            }
                        }
                        .filaLista()
                    } else {
                        EstadoVacio(icono: "key", titulo: "Sin contrato",
                                    mensaje: "Todavía no hay ningún contrato asociado a tu cuenta.")
                            .listRowBackground(Color.clear)
                    }
                }
                .estiloLista()
            }
            .navigationTitle("Mi alquiler")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { verAvisos = true } label: {
                        Image(systemName: noLeidas > 0 ? "bell.badge" : "bell")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Tema.Color.negativo, Tema.Color.texto)
                    }
                    .accessibilityLabel(noLeidas > 0 ? "Avisos, \(noLeidas) sin leer" : "Avisos")
                    .accessibilityIdentifier("campana")
                }
            }
            .navigationDestination(isPresented: $verAvisos) {
                NotificacionesView(alCambiar: { await contarNoLeidas() }, conDestinos: false)
            }
            .refreshable { await cargar() }
            .task {
                await cargar()
                await contarNoLeidas()
            }
            .visorPDF($documento)
            .alertaError($error)
            .fianza(modeloFianza, contrato: contratoPrincipal?.id, renta: contratoPrincipal?.precioMensual ?? 0, api: sesion.api)
            .actualizacionRenta(modeloRenta, contrato: contratoPrincipal?.id, gestor: false, api: sesion.api)
            .firmas(modeloFirmas, contrato: contratoPrincipal?.id, api: sesion.api)
        }
    }

    /// El contrato que se muestra: el activo o, si no hay, el último.
    private var contratoPrincipal: Contrato? {
        guard let contratos = estado.valor?.0 else { return nil }
        return contratos.first(where: \.activo) ?? contratos.first
    }

    private func contarNoLeidas() async {
        if let total = try? await sesion.api.enviar(.notificacionesNoLeidas) { noLeidas = total.total }
    }

    private func cargar() async {
        do {
            async let c = sesion.api.enviar(.contratos())
            async let p = sesion.api.enviar(.pagos())
            let datos = try await (c, p)
            estado = .cargado(datos)
            if let activo = datos.0.first(where: \.activo) { await AvisosLocales.programarInquilino(renta: activo.precioMensual) }
            await sesion.registrarDispositivo()
        } catch let e as APIError {
            if case .noAutorizado = e { return }
            if estado.valor == nil { estado = .error(e.localizedDescription) } else { error = e.localizedDescription }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func abrirRecibo(_ p: Pago) async {
        do {
            documento = DocumentoPDF(titulo: "Recibo \(p.recibo ?? "")".trimmingCharacters(in: .whitespaces),
                                     datos: try await sesion.api.descargar(Rutas.reciboPago(p.id)))
            if p.recibo == nil { await cargar() }
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func abrirFirmado(_ c: Contrato) async {
        do {
            documento = DocumentoPDF(titulo: "Mi contrato firmado", datos: try await sesion.api.descargar(Rutas.pdfFirmado(c.id)))
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func abrirPDF(_ c: Contrato) async {
        do {
            documento = DocumentoPDF(titulo: "Mi contrato", datos: try await sesion.api.descargar(Rutas.pdfContrato(c.id)))
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
