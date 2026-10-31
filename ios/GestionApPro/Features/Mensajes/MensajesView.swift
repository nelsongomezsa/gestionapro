import SwiftUI

/// Bandeja: una fila por conversación (general del contrato o de una incidencia).
struct ConversacionesView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<[Conversacion]> = .cargando
    @State private var miContrato: Int?

    private var esInquilino: Bool { sesion.usuario?.rol == .inquilino }

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { lista in
            List {
                if lista.isEmpty {
                    EstadoVacio(icono: "bubble.left.and.bubble.right", titulo: "Sin mensajes",
                                mensaje: esInquilino ? "Escribe a tu propietario cuando lo necesites."
                                                     : "Escribe a un inquilino desde su contrato.")
                        .listRowBackground(Color.clear)
                }
                if esInquilino, let id = miContrato, !lista.contains(where: { $0.idContrato == id && $0.idIncidencia == nil }) {
                    Section {
                        NavigationLink(value: HiloMensajes.contrato(id)) {
                            Label("Escribir a mi propietario", systemImage: "square.and.pencil")
                        }
                        .accessibilityIdentifier("botonEscribirPropietario")
                    }
                    .filaLista()
                }
                Section {
                    ForEach(lista) { c in
                        NavigationLink(value: c.idIncidencia.map(HiloMensajes.incidencia) ?? .contrato(c.idContrato)) {
                            FilaConversacion(conversacion: c)
                        }
                        .accessibilityIdentifier("filaConversacion")
                    }
                }
                .filaLista()
            }
            .estiloLista()
        }
        .navigationTitle("Mensajes")
        .navigationDestination(for: HiloMensajes.self) { ChatView(hilo: $0) }
        .refreshable { await cargar() }
        .task { await cargar() }
    }

    private func cargar() async {
        do {
            estado = .cargado(try await sesion.api.enviar(.conversaciones))
            if esInquilino, miContrato == nil, let contratos = try? await sesion.api.enviar(.contratos()) {
                miContrato = (contratos.first(where: \.activo) ?? contratos.first)?.id
            }
        } catch .noAutorizado {
        } catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) }
        }
    }
}

struct FilaConversacion: View {
    let conversacion: Conversacion

    var body: some View {
        HStack(alignment: .top, spacing: Tema.Espacio.s) {
            AvatarIniciales(nombre: conversacion.con, tamano: Tema.Tamano.avatarFila)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversacion.con).font(Tema.Fuente.subtitulo)
                    Spacer(minLength: Tema.Espacio.xs)
                    Text(conversacion.fecha, format: .relative(presentation: .named).locale(Formato.locale))
                        .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                }
                Text(conversacion.asunto).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                HStack(alignment: .top) {
                    Text((conversacion.ultimoMio ? "Tú: " : "") + conversacion.ultimoMensaje)
                        .font(conversacion.sinLeer > 0 ? Tema.Fuente.detalle.weight(.semibold) : Tema.Fuente.detalle)
                        .foregroundStyle(conversacion.sinLeer > 0 ? Tema.Color.texto : Tema.Color.textoSecundario)
                        .lineLimit(2)
                    Spacer(minLength: Tema.Espacio.xs)
                    if conversacion.sinLeer > 0 {
                        Text("\(conversacion.sinLeer)")
                            .font(Tema.Fuente.etiqueta).foregroundStyle(Tema.Color.sobrePrimario)
                            .padding(.horizontal, Tema.Espacio.xs).padding(.vertical, Tema.Espacio.linea)
                            .background(Tema.Color.primarioRelleno, in: .capsule)
                            .accessibilityLabel("\(conversacion.sinLeer) sin leer")
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Conversación: burbujas (las mías a la derecha) y caja para escribir. Se refresca sola cada 15 s.
struct ChatView: View {
    @Environment(SesionStore.self) private var sesion
    let hilo: HiloMensajes

    @State private var mensajes: [MensajeChat] = []
    @State private var cargado = false
    @State private var texto = ""
    @State private var enviando = false
    @State private var error: String?
    @FocusState private var escribiendo: Bool

    private var puedeEnviar: Bool { !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !enviando }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                LazyVStack(spacing: Tema.Espacio.xs) {
                    if cargado && mensajes.isEmpty {
                        EstadoVacio(icono: "bubble.left", titulo: "Aún no hay mensajes", mensaje: "Escribe el primero.")
                            .padding(.top, Tema.Espacio.xl)
                    }
                    ForEach(mensajes) { m in
                        Burbuja(mensaje: m).id(m.id)
                    }
                }
                .padding(Tema.Espacio.m)
            }
            .background(Tema.Color.fondo)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: mensajes.last?.id) { _, ultimo in
                if let ultimo { withAnimation(Tema.Movimiento.suave) { scroll.scrollTo(ultimo, anchor: .bottom) } }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .bottom, spacing: Tema.Espacio.xs) {
                TextField("Mensaje", text: $texto, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($escribiendo)
                    .padding(.horizontal, Tema.Espacio.s)
                    .padding(.vertical, Tema.Espacio.xs)
                    .background(Tema.Color.superficie, in: .rect(cornerRadius: Tema.Radio.grande))
                    .overlay(RoundedRectangle(cornerRadius: Tema.Radio.grande).strokeBorder(Tema.Color.borde))
                    .accessibilityIdentifier("campoMensaje")
                Button { Task { await enviar() } } label: {
                    Image(systemName: "arrow.up.circle.fill").font(Tema.Fuente.iconoGrande)
                        .foregroundStyle(puedeEnviar ? Tema.Color.primarioRelleno : Tema.Color.textoSecundario)
                }
                .disabled(!puedeEnviar)
                .accessibilityLabel("Enviar")
                .accessibilityIdentifier("botonEnviarMensaje")
            }
            .padding(.horizontal, Tema.Espacio.m)
            .padding(.vertical, Tema.Espacio.xs)
            .background(.bar)
        }
        .navigationTitle("Mensajes")
        .navigationBarTitleDisplayMode(.inline)
        .alertaError($error)
        .task {
            // Mientras la conversación está abierta se refresca cada 15 s (las push llegarán en la fase 8).
            while !Task.isCancelled {
                await cargar()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    private func cargar() async {
        do {
            mensajes = try await sesion.api.enviar(.mensajes(hilo))
            cargado = true
        } catch .noAutorizado {
        } catch {
            if !cargado { self.error = error.localizedDescription }
        }
    }

    private func enviar() async {
        let limpio = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpio.isEmpty else { return }
        enviando = true
        defer { enviando = false }
        do {
            mensajes.append(try await sesion.api.enviar(.enviarMensaje(hilo, texto: limpio)))
            texto = ""
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct Burbuja: View {
    let mensaje: MensajeChat

    var body: some View {
        HStack {
            if mensaje.mio { Spacer(minLength: Tema.Espacio.xl) }
            VStack(alignment: mensaje.mio ? .trailing : .leading, spacing: Tema.Espacio.linea) {
                Text(mensaje.texto)
                    .font(Tema.Fuente.cuerpo)
                    .foregroundStyle(mensaje.mio ? Tema.Color.sobrePrimario : Tema.Color.texto)
                    .padding(.horizontal, Tema.Espacio.s)
                    .padding(.vertical, Tema.Espacio.xs)
                    .background(mensaje.mio ? Tema.Color.primarioRelleno : Tema.Color.superficie,
                                in: .rect(cornerRadius: Tema.Radio.grande))
                Text(mensaje.fecha.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Formato.locale))
                     + (mensaje.mio && mensaje.leido ? " · Leído" : ""))
                    .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
            if !mensaje.mio { Spacer(minLength: Tema.Espacio.xl) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mensaje.mio ? "Tú" : mensaje.autor): \(mensaje.texto)")
    }
}
