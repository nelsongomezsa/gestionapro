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
                    VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                        InsigniaEstado(texto: c.activo ? c.vencimiento.texto : "Finalizado",
                                       tono: c.activo ? c.vencimiento.tono : .neutro)
                        Text(c.inquilino.nombre).font(Tema.Fuente.titulo)
                        Text("Hab. \(c.habitacion.numero) · \(c.piso.direccion), \(c.piso.ciudad)")
                            .foregroundStyle(Tema.Color.textoSecundario)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack(spacing: Tema.Espacio.s) {
                        TarjetaKPI(titulo: "Renta mensual", valor: Formato.euros(c.precioMensual), icono: "eurosign")
                        TarjetaKPI(titulo: c.diasRestantes >= 0 ? "Días restantes" : "Finalizó hace",
                                   valor: "\(abs(c.diasRestantes))", icono: "calendar", tono: c.activo ? c.vencimiento.tono : .neutro)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("Fechas") {
                    LabeledContent("Inicio", value: c.fechaInicio.formatted(FormatoFecha.larga))
                    LabeledContent("Fin", value: c.fechaFin.formatted(FormatoFecha.larga))
                }

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
                }

                if esGestor && c.activo {
                    Section {
                        Button("Finalizar contrato", role: .destructive) { confirmarFin = true }
                            .frame(maxWidth: .infinity)
                    } footer: {
                        Text("La fecha de fin pasa a ser hoy y la habitación queda disponible.")
                    }
                }
            }
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
        do {
            estado = .cargado(try await sesion.api.enviar(.finalizarContrato(id: c.id)))
            alCambiar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
