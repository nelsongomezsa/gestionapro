import SwiftUI

/// Lo que se crea desde el botón «+» (y desde Siri), más el panel del asistente.
enum AccesoRapido: String, Identifiable {
    case pago, incidencia, gasto, mensajeNuevo, mensajes, asistente
    var id: String { rawValue }

    var titulo: LocalizedStringKey {
        switch self {
        case .pago: "Cobro"
        case .incidencia: "Incidencia"
        case .gasto: "Gasto"
        case .mensajeNuevo: "Mensaje nuevo"
        case .mensajes: "Mensajes"
        case .asistente: "Asistente"
        }
    }

    var icono: String {
        switch self {
        case .pago: "eurosign.circle"
        case .incidencia: "wrench.and.screwdriver"
        case .gasto: "cart"
        case .mensajeNuevo: "square.and.pencil"
        case .mensajes: "bubble.left.and.bubble.right"
        case .asistente: "sparkles"
        }
    }
}

/// Hoja del botón «+» (a la derecha de la barra de pestañas): lo que más se crea, a un toque.
struct MenuCrear: View {
    let opciones: [AccesoRapido]
    let elegir: (AccesoRapido) -> Void

    var body: some View {
        NavigationStack {
            List(opciones) { o in
                Button { elegir(o) } label: {
                    Label { Text(o.titulo).foregroundStyle(Tema.Color.texto) } icon: {
                        IconoSeccion(icono: o.icono, relleno: Tema.Color.iconoAzul)
                    }
                    .frame(minHeight: 44)
                }
                .accessibilityIdentifier("crear-\(o.rawValue)")
            }
            .navigationTitle("Crear")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(CGFloat(130 + opciones.count * 64)), .medium])
        .presentationDragIndicator(.visible)
    }
}

/// Mensaje nuevo: se elige el contrato (inquilino) y se abre su conversación.
struct NuevoMensajeView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var contratos: [Contrato]?

    var body: some View {
        NavigationStack {
            Group {
                if let contratos {
                    if contratos.isEmpty {
                        EstadoVacio(icono: "bubble.left.and.bubble.right", titulo: "Sin contratos activos",
                                    mensaje: "Los mensajes van ligados a un contrato.")
                    } else {
                        List(contratos) { c in
                            NavigationLink(value: c) {
                                HStack(spacing: Tema.Espacio.s) {
                                    AvatarIniciales(nombre: c.inquilino.nombre, tamano: Tema.Tamano.icono)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.inquilino.nombre).foregroundStyle(Tema.Color.texto)
                                        Text("Hab. \(c.habitacion.numero) · \(c.piso.direccion)")
                                            .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario).lineLimit(1)
                                    }
                                }
                            }
                            .accessibilityIdentifier("contratoMensajeNuevo")
                        }
                    }
                } else {
                    EsqueletoCarga()
                }
            }
            .navigationTitle("Mensaje nuevo")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Contrato.self) { c in ChatView(hilo: .contrato(c.id), titulo: c.inquilino.nombre) }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } } }
            .task {
                contratos = ((try? await sesion.api.enviar(.contratos(filtro: .activos))) ?? [])
                    .sorted { $0.inquilino.nombre.localizedStandardCompare($1.inquilino.nombre) == .orderedAscending }
            }
        }
    }
}

/// Aviso de mensaje nuevo arriba de la pantalla, con respuesta sin salir de donde estás.
struct AvisoMensaje: View {
    let conversacion: Conversacion
    let responder: () -> Void
    let cerrar: () -> Void

    var body: some View {
        HStack(spacing: Tema.Espacio.s) {
            AvatarIniciales(nombre: conversacion.con, tamano: Tema.Tamano.icono)
            VStack(alignment: .leading, spacing: 2) {
                Text(conversacion.con).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto).lineLimit(1)
                Text(conversacion.ultimoMensaje).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario).lineLimit(2)
            }
            Spacer(minLength: Tema.Espacio.xs)
            Button("Responder", action: responder)
                .buttonStyle(.glassProminent)
                .tint(Tema.Color.primarioRelleno)
                .accessibilityIdentifier("responderAviso")
        }
        .padding(Tema.Espacio.s)
        .fondoCristal(en: .rect(cornerRadius: Tema.Radio.grande), interactivo: false)
        .padding(.horizontal, Tema.Espacio.m)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mensaje nuevo de \(conversacion.con)")
        .gesture(DragGesture(minimumDistance: 10).onEnded { if $0.translation.height < 0 { cerrar() } })
    }
}

/// Nuevo gasto desde cualquier pantalla: primero el piso, luego el formulario de siempre.
struct NuevoGastoRapidoView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var pisos: [Piso] = []

    var body: some View {
        NavigationStack {
            List(pisos) { p in
                NavigationLink(value: PisoBreve(id: p.id, direccion: p.direccion, ciudad: p.ciudad.nombre)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.direccion).foregroundStyle(Tema.Color.texto)
                        Text(p.ciudad.nombre).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    }
                }
            }
            .navigationTitle("¿De qué piso?")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PisoBreve.self) { piso in
                GastoFormView(piso: piso, gasto: nil) {
                    NotificationCenter.default.post(name: .datosCambiados, object: nil)
                    cerrar()
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } } }
            .task { pisos = (try? await sesion.api.enviar(.pisos)) ?? [] }
        }
    }
}

extension Notification.Name {
    /// Algo se creó desde un acceso rápido: las pantallas abiertas recargan.
    static let datosCambiados = Notification.Name("datosCambiados")
}

/// Cobro desde cualquier pantalla: los pendientes del mes a un toque (con el importe ya puesto)
/// y, debajo, "Otro pago" para elegir contrato a mano.
struct CobroRapidoView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var pendientes: [ResumenPagos.Pendiente]?
    @State private var elegido: PagoPrellenado?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let pendientes {
                        if pendientes.isEmpty {
                            Label("Todo cobrado este mes", systemImage: "checkmark.seal")
                                .foregroundStyle(Tema.Color.positivo)
                        }
                        ForEach(pendientes) { p in
                            Button { elegido = PagoPrellenado(idContrato: p.idContrato, importe: p.importe) } label: {
                                HStack(spacing: Tema.Espacio.s) {
                                    AvatarIniciales(nombre: p.inquilino.nombre, tamano: Tema.Tamano.icono)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.inquilino.nombre).foregroundStyle(Tema.Color.texto)
                                        Text("Hab. \(p.numeroHabitacion) · \(p.piso.direccion)")
                                            .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario).lineLimit(1)
                                    }
                                    Spacer(minLength: Tema.Espacio.xs)
                                    Text(Formato.euros(p.importe)).font(Tema.Fuente.cifraPequena).foregroundStyle(Tema.Color.texto)
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Cobrar \(Formato.euros(p.importe)) a \(p.inquilino.nombre)")
                            .accessibilityIdentifier("cobroPendiente")
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Pendientes de este mes")
                }
                Section {
                    Button("Otro pago…", systemImage: "plus.circle") { elegido = PagoPrellenado(idContrato: nil, importe: nil) }
                }
            }
            .navigationTitle("Registrar pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } } }
            .task { pendientes = (try? await sesion.api.enviar(.resumenPagos(mes: .actual)))?.pendientes ?? [] }
            .sheet(item: $elegido) { p in
                PagoFormView(idContrato: p.idContrato, importe: p.importe) { _ in
                    NotificationCenter.default.post(name: .datosCambiados, object: nil)
                    cerrar()
                }
            }
        }
    }
}
