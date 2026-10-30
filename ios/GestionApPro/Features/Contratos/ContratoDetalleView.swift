import SwiftUI

/// Detalle de un contrato: PDF, recordatorio, mapa, contacto y finalizar.
struct ContratoDetalleView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.openURL) private var abrirURL
    let id: Int
    var alCambiar: () -> Void = {}

    @State private var estado: EstadoCarga<Contrato> = .cargando
    @State private var documento: DocumentoPDF?
    @State private var compartir: Compartible?
    @State private var verMapa = false
    @State private var confirmarFin = false
    @State private var trabajando = false
    @State private var error: String?

    private var esGestor: Bool { sesion.usuario?.rol.gestionaPisos == true }

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { c in
            List {
                Section {
                    VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                        VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
                            Text(c.inquilino.nombre)
                                .font(Tema.Fuente.titulo)
                                .foregroundStyle(Tema.Color.texto)
                                .accessibilityAddTraits(.isHeader)
                            Text("Habitación \(c.habitacion.numero) · \(c.piso.direccion), \(c.piso.ciudad)")
                                .font(Tema.Fuente.detalle)
                                .foregroundStyle(Tema.Color.textoSecundario)
                        }
                        TarjetaHero(titulo: "Renta mensual", valor: Formato.euros(c.precioMensual),
                                    accesorio: AnyView(InsigniaEstado(texto: c.activo ? c.vencimiento.estadoCorto : "Finalizado",
                                                                      tono: c.activo ? c.vencimiento.tono : .neutro))) {
                            VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                                BarraProgreso(valor: Self.transcurrido(c), tono: c.activo ? c.vencimiento.tono : .neutro)
                                Text(c.activo ? (c.diasRestantes == 0 ? "Vence hoy" : "Quedan \(c.diasRestantes) días")
                                              : "Finalizó hace \(abs(c.diasRestantes)) días")
                                    .font(Tema.Fuente.nota)
                                    .foregroundStyle(Tema.Color.textoSecundario)
                            }
                            ParDatos {
                                DatoCompacto(titulo: "Inicio", valor: c.fechaInicio.formatted(FormatoFecha.corta))
                            } derecha: {
                                DatoCompacto(titulo: "Fin", valor: c.fechaFin.formatted(FormatoFecha.corta))
                            }
                        }
                    }
                    .padding(.top, Tema.Espacio.xs)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section("Documentos y avisos") {
                    Button { Task { await abrirPDF(c) } } label: {
                        Label("Contrato de arrendamiento (PDF)", systemImage: "doc.text.magnifyingglass")
                    }
                    .disabled(trabajando)
                    if esGestor {
                        Button {
                            compartir = Compartible(elementos: [Recordatorio.cuerpo(c)], asunto: Recordatorio.asunto(c))
                        } label: {
                            Label("Enviar recordatorio de pago", systemImage: "bell.badge")
                        }
                    }
                    Button { verMapa = true } label: { Label("Ver en el mapa", systemImage: "map") }
                }
                .filaLista()

                if esGestor, c.inquilino.telefono != nil || c.inquilino.email != nil {
                    Section("Contacto") {
                        if let t = c.inquilino.telefono, let url = Contacto.llamada(t) {
                            Button { abrirURL(url) } label: { Label("Llamar · \(t)", systemImage: "phone") }
                        }
                        if let t = c.inquilino.telefono, let url = Contacto.whatsApp(t) {
                            Button { abrirURL(url) } label: { Label("WhatsApp", systemImage: "message") }
                        }
                        if let e = c.inquilino.email, let url = Contacto.email(e, asunto: Recordatorio.asunto(c)) {
                            Button { abrirURL(url) } label: { Label("Email · \(e)", systemImage: "envelope") }
                        }
                    }
                    .filaLista()
                }

                if esGestor && c.activo {
                    Section {
                        Button("Finalizar contrato", role: .destructive) { confirmarFin = true }
                            .disabled(trabajando)
                            .frame(maxWidth: .infinity)
                    } footer: {
                        Text("La fecha de fin pasa a ser hoy y la habitación queda disponible.")
                    }
                    .filaLista()
                }
            }
            .estiloLista()
            .navigationTitle("Contrato")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $verMapa) {
                NavigationStack {
                    MapaDireccion(titulo: c.piso.direccion, direccion: c.piso.direccion, ciudad: c.piso.ciudad)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { verMapa = false } } }
                }
            }
            .confirmationDialog("¿Finalizar el contrato de \(c.inquilino.nombre)?", isPresented: $confirmarFin, titleVisibility: .visible) {
                Button("Finalizar hoy", role: .destructive) { Task { await finalizar(c) } }
            }
        }
        .task { await cargar() }
        .visorPDF($documento)
        .hojaCompartir($compartir)
        .alertaError($error)
    }

    /// Parte del contrato ya transcurrida (0 a 1), para la barra de la tarjeta principal.
    static func transcurrido(_ c: Contrato, hoy: Date = .now) -> Double {
        let total = c.fechaFin.timeIntervalSince(c.fechaInicio)
        guard total > 0 else { return 1 }
        return min(max(hoy.timeIntervalSince(c.fechaInicio) / total, 0), 1)
    }

    private func cargar() async {
        do {
            estado = .cargado(try await sesion.api.enviar(.contrato(id: id)))
        } catch .noAutorizado {
        } catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) } else { self.error = error.localizedDescription }
        }
    }

    private func abrirPDF(_ c: Contrato) async {
        trabajando = true
        defer { trabajando = false }
        do {
            let datos = try await sesion.api.descargar(Rutas.pdfContrato(c.id))
            documento = DocumentoPDF(titulo: "Contrato \(c.inquilino.nombre)", datos: datos)
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func finalizar(_ c: Contrato) async {
        trabajando = true
        defer { trabajando = false }
        do {
            estado = .cargado(try await sesion.api.enviar(.finalizarContrato(id: c.id)))
            alCambiar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
