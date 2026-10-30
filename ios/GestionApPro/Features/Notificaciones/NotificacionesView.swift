import SwiftUI

/// Avisos del usuario (campana del escritorio). Al tocar uno se marca como leído y se abre
/// su pantalla, como RutasNotificacion.
struct NotificacionesView: View {
    @Environment(SesionStore.self) private var sesion
    /// Abre la pantalla del aviso en la pila de Inicio.
    var abrir: (DestinoInicio) -> Void = { _ in }
    var alCambiar: () async -> Void = {}

    @State private var estado: EstadoCarga<[Notificacion]> = .cargando
    @State private var soloNoLeidas = false
    @State private var error: String?

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { lista in
            let visibles = soloNoLeidas ? lista.filter { !$0.leida } : lista
            List {
                Picker("Mostrar", selection: $soloNoLeidas) {
                    Text("Todas").tag(false)
                    Text("Sin leer (\(lista.filter { !$0.leida }.count))").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if visibles.isEmpty {
                    EstadoVacio(icono: "bell.slash", titulo: "Sin avisos", mensaje: "Estás al día.")
                        .listRowBackground(Color.clear)
                }
                ForEach(visibles) { n in
                    // Un botón y no un NavigationLink con un gesto añadido: el gesto anulaba la navegación.
                    Button {
                        Task { await marcar(n) }
                        if let destino = n.destino.flatMap(Self.destino) { abrir(destino) }
                    } label: {
                        HStack {
                            FilaNotificacion(notificacion: n)
                            if n.destino != nil {
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                    .foregroundStyle(Tema.Color.textoSecundario)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("filaNotificacion")
                    .swipeActions {
                        if !n.leida {
                            Button("Leída", systemImage: "envelope.open") { Task { await marcar(n) } }.tint(Tema.Color.primario)
                        }
                    }
                }
            }
        }
        .navigationTitle("Notificaciones")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Marcar todas como leídas", systemImage: "checkmark.circle") { Task { await marcarTodas() } }
                    .disabled(estado.valor?.allSatisfy(\.leida) ?? true)
            }
        }
        .refreshable { await cargar() }
        .task { await cargar() }
        .alertaError($error)
    }

    nonisolated static func destino(_ d: Notificacion.Destino) -> DestinoInicio? {
        switch d.pantalla {
        case "CONTRATO": .contrato(d.id)
        case "INCIDENCIA": .incidencia(d.id)
        case "HABITACION": .habitacion(d.id)
        default: nil
        }
    }

    private func cargar() async {
        do {
            estado = .cargado(try await sesion.api.enviar(.notificaciones()))
        } catch .noAutorizado {
        } catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) } else { self.error = error.localizedDescription }
        }
    }

    private func marcar(_ n: Notificacion) async {
        guard !n.leida else { return }
        do {
            let actualizada = try await sesion.api.enviar(.marcarLeida(n.id))
            if case var .cargado(lista) = estado, let i = lista.firstIndex(where: { $0.id == n.id }) {
                lista[i] = actualizada
                estado = .cargado(lista)
            }
            await alCambiar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func marcarTodas() async {
        do {
            _ = try await sesion.api.enviar(.marcarTodasLeidas)
            await cargar()
            await alCambiar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct FilaNotificacion: View {
    let notificacion: Notificacion

    var body: some View {
        HStack(alignment: .top, spacing: Tema.Espacio.s) {
            Image(systemName: notificacion.icono)
                .foregroundStyle(notificacion.tono.color)
                .frame(width: 32, height: 32)
                .background(notificacion.tono.color.opacity(0.14), in: .circle)
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                HStack {
                    Text(notificacion.titulo).font(notificacion.leida ? Tema.Fuente.cuerpo : Tema.Fuente.subtitulo)
                    Spacer()
                    if !notificacion.leida {
                        Circle().fill(Tema.Color.primario).frame(width: 8, height: 8).accessibilityLabel("Sin leer")
                    }
                }
                if let d = notificacion.descripcion {
                    Text(d).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario).lineLimit(2)
                }
                Text(notificacion.fecha, format: .relative(presentation: .named).locale(Formato.locale))
                    .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
        }
        .opacity(notificacion.leida ? 0.7 : 1)
        .accessibilityElement(children: .combine)
    }
}
