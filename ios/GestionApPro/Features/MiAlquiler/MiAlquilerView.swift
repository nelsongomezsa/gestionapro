import SwiftUI

/// Pestaña del INQUILINO: su contrato, su habitación y sus pagos (la API solo le devuelve lo suyo).
struct MiAlquilerView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<([Contrato], [Pago])> = .cargando
    @State private var documento: DocumentoPDF?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { datos in
                let (contratos, pagos) = datos
                List {
                    if let c = contratos.first(where: \.activo) ?? contratos.first {
                        Section {
                            VStack(alignment: .leading, spacing: Tema.Espacio.s) {
                                InsigniaEstado(texto: c.activo ? c.vencimiento.texto : "Finalizado",
                                               tono: c.activo ? c.vencimiento.tono : .neutro)
                                Text("Habitación \(c.habitacion.numero)").font(Tema.Fuente.titulo)
                                Label("\(c.piso.direccion), \(c.piso.ciudad)", systemImage: "mappin.and.ellipse")
                                    .foregroundStyle(Tema.Color.textoSecundario)
                            }
                            .listRowBackground(Color.clear)
                        }
                        Section("Contrato") {
                            LabeledContent("Renta mensual", value: Formato.euros(c.precioMensual))
                            LabeledContent("Desde", value: c.fechaInicio.formatted(FormatoFecha.larga))
                            LabeledContent("Hasta", value: c.fechaFin.formatted(FormatoFecha.larga))
                            Button { Task { await abrirPDF(c) } } label: {
                                Label("Ver contrato (PDF)", systemImage: "doc.text.magnifyingglass")
                            }
                        }
                        Section("Mis pagos") {
                            if pagos.isEmpty {
                                Text("Sin pagos registrados").foregroundStyle(Tema.Color.textoSecundario)
                            }
                            ForEach(pagos) { p in
                                FilaMetrica(titulo: p.fechaPago.formatted(FormatoFecha.larga), valor: Formato.euros(p.cantidad),
                                            nota: p.metodoPago.nombre)
                            }
                        }
                    } else {
                        EstadoVacio(icono: "key", titulo: "Sin contrato",
                                    mensaje: "Todavía no hay ningún contrato asociado a tu cuenta.")
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Mi alquiler")
            .refreshable { await cargar() }
            .task { await cargar() }
            .visorPDF($documento)
            .alertaError($error)
        }
    }

    private func cargar() async {
        do {
            async let c = sesion.api.enviar(.contratos())
            async let p = sesion.api.enviar(.pagos())
            estado = .cargado(try await (c, p))
        } catch let e as APIError {
            if case .noAutorizado = e { return }
            if estado.valor == nil { estado = .error(e.localizedDescription) } else { error = e.localizedDescription }
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
