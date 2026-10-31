import SwiftUI

/// Asistente GestionAp: preguntas sobre la cartera y acciones propuestas que se confirman aquí.
/// Sin clave en el servidor aparece desactivado con su explicación.
struct AsistenteView: View {
    @Environment(SesionStore.self) private var sesion

    struct Entrada: Identifiable {
        let id = UUID()
        let delUsuario: Bool
        let texto: String
        var acciones: [AccionAsistente] = []
    }

    @State private var estado: EstadoAsistente?
    @State private var conversacion: [Entrada] = []
    @State private var texto = ""
    @State private var pensando = false
    @State private var hechas: Set<String> = []
    @State private var compartir: Compartible?
    @State private var error: String?

    private static let sugerencias = ["¿Quién me debe este mes?", "Explícame el informe del mes",
                                      "¿Qué incidencias llevan más tiempo abiertas?", "¿Qué contratos vencen pronto?"]

    var body: some View {
        Group {
            if let e = estado, !e.disponible {
                EstadoVacio(icono: "sparkles", titulo: "Asistente desactivado", mensaje: e.mensaje)
                    .accessibilityIdentifier("asistenteDesactivado")
            } else {
                chat
            }
        }
        .background(Tema.Color.fondo)
        .navigationTitle("Asistente")
        .navigationBarTitleDisplayMode(.inline)
        .hojaCompartir($compartir)
        .alertaError($error)
        .task { estado = try? await sesion.api.enviar(.estadoAsistente) }
    }

    private var chat: some View {
        ScrollViewReader { scroll in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Tema.Espacio.s) {
                    if conversacion.isEmpty {
                        Text("Pregúntame por tu cartera. Si me pides registrar un pago o crear una incidencia, te lo preparo y tú lo confirmas.")
                            .font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                        ForEach(Self.sugerencias, id: \.self) { s in
                            Button { Task { await preguntar(s) } } label: {
                                Label(s, systemImage: "sparkles").font(Tema.Fuente.detalle)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    ForEach(conversacion) { e in
                        VStack(alignment: e.delUsuario ? .trailing : .leading, spacing: Tema.Espacio.xs) {
                            Text(e.texto)
                                .font(Tema.Fuente.cuerpo)
                                .foregroundStyle(e.delUsuario ? Tema.Color.sobrePrimario : Tema.Color.texto)
                                .padding(.horizontal, Tema.Espacio.s).padding(.vertical, Tema.Espacio.xs)
                                .background(e.delUsuario ? Tema.Color.primarioRelleno : Tema.Color.superficie,
                                            in: .rect(cornerRadius: Tema.Radio.grande))
                                .textSelection(.enabled)
                            ForEach(e.acciones, id: \.self) { accion in tarjeta(accion) }
                        }
                        .frame(maxWidth: .infinity, alignment: e.delUsuario ? .trailing : .leading)
                        .id(e.id)
                    }
                    if pensando {
                        HStack { ProgressView(); Text("Pensando…").foregroundStyle(Tema.Color.textoSecundario) }
                    }
                }
                .padding(Tema.Espacio.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: conversacion.count) { _, _ in
                if let ultimo = conversacion.last?.id { withAnimation(Tema.Movimiento.suave) { scroll.scrollTo(ultimo, anchor: .bottom) } }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Tema.Espacio.xxs) {
                HStack(alignment: .bottom, spacing: Tema.Espacio.xs) {
                    TextField("Pregunta al asistente", text: $texto, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, Tema.Espacio.s).padding(.vertical, Tema.Espacio.xs)
                        .background(Tema.Color.superficie, in: .rect(cornerRadius: Tema.Radio.grande))
                        .overlay(RoundedRectangle(cornerRadius: Tema.Radio.grande).strokeBorder(Tema.Color.borde))
                        .accessibilityIdentifier("campoAsistente")
                    Button { Task { await preguntar(texto) } } label: {
                        Image(systemName: "arrow.up.circle.fill").font(Tema.Fuente.iconoGrande)
                            .foregroundStyle(texto.isEmpty || pensando ? Tema.Color.textoSecundario : Tema.Color.primarioRelleno)
                    }
                    .disabled(texto.trimmingCharacters(in: .whitespaces).isEmpty || pensando)
                    .accessibilityLabel("Enviar")
                }
                if let e = estado {
                    Text("\(e.usadosHoy) de \(e.limiteDiario) consultas hoy · respuestas generadas por IA, revísalas")
                        .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                }
            }
            .padding(.horizontal, Tema.Espacio.m).padding(.vertical, Tema.Espacio.xs)
            .background(.bar)
        }
    }

    /// Tarjeta de una acción propuesta: no se hace nada hasta pulsar Confirmar.
    private func tarjeta(_ a: AccionAsistente) -> some View {
        let clave = a.resumen
        return VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            Label(a.resumen, systemImage: icono(a.tipo)).font(Tema.Fuente.detalle)
            if hechas.contains(clave) {
                Label("Hecho", systemImage: "checkmark.circle.fill").foregroundStyle(Tema.Color.positivo).font(Tema.Fuente.nota)
            } else {
                Button(a.tipo == .recordatorio ? "Revisar y enviar" : "Confirmar") { Task { await ejecutar(a) } }
                    .buttonStyle(.borderedProminent).tint(Tema.Color.primarioRelleno)
                    .accessibilityIdentifier("botonConfirmarAccion")
            }
        }
        .padding(Tema.Espacio.s)
        .background(Tema.Color.primarioSuave, in: .rect(cornerRadius: Tema.Radio.grande))
    }

    private func icono(_ t: AccionAsistente.Tipo) -> String {
        switch t {
        case .registrarPago: "eurosign.circle"
        case .crearIncidencia: "wrench.and.screwdriver"
        case .recordatorio: "bell.badge"
        }
    }

    private func preguntar(_ pregunta: String) async {
        let limpia = pregunta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty else { return }
        let historial = conversacion.suffix(10).map { PreguntaAsistente.Turno(delUsuario: $0.delUsuario, texto: $0.texto) }
        conversacion.append(Entrada(delUsuario: true, texto: limpia))
        texto = ""
        pensando = true
        defer { pensando = false }
        do {
            let r = try await sesion.api.enviar(.preguntarAsistente(PreguntaAsistente(mensaje: limpia, historial: historial)))
            conversacion.append(Entrada(delUsuario: false, texto: r.respuesta, acciones: r.acciones))
            estado = EstadoAsistente(disponible: true, mensaje: estado?.mensaje ?? "", usadosHoy: r.usadosHoy, limiteDiario: r.limiteDiario)
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Las acciones usan los endpoints de siempre, con los permisos del usuario.
    private func ejecutar(_ a: AccionAsistente) async {
        do {
            switch a.tipo {
            case .registrarPago:
                guard let id = a.datos.idContrato, let cantidad = a.datos.cantidad, let fecha = a.datos.fechaPago else { return }
                _ = try await sesion.api.enviar(.registrarPago(PagoRequest(idContrato: id, cantidad: cantidad,
                                                                           metodoPago: a.datos.metodoPago ?? .transferencia,
                                                                           fechaPago: fecha)))
            case .crearIncidencia:
                guard let id = a.datos.idHabitacion, let d = a.datos.descripcion else { return }
                _ = try await sesion.api.enviar(.crearIncidencia(IncidenciaRequest(idHabitacion: id, descripcion: d)))
            case .recordatorio:
                compartir = Compartible(elementos: [a.datos.texto ?? ""], asunto: "Recordatorio de pago")
            }
            hechas.insert(a.resumen)
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
