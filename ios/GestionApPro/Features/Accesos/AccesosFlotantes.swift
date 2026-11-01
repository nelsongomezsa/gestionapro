import SwiftUI

/// Acciones que se abren desde los accesos flotantes.
enum AccesoRapido: String, Identifiable {
    case pago, incidencia, gasto, mensajes, asistente
    var id: String { rawValue }
}

/// Barra de accesos rápidos sobre la barra de pestañas (accesorio de iOS 26: cristal fundido con
/// la barra, sin tapar el contenido): Mensajes con su contador, registrar pago, incidencia y gasto.
struct BarraAccesos: View {
    @Environment(BuzonMensajes.self) private var buzon
    @Binding var abierto: AccesoRapido?

    var body: some View {
        HStack(spacing: 0) {
            boton("Mensajes", icono: "bubble.left.and.bubble.right", acceso: .mensajes, id: "accesoMensajes")
                .overlay(alignment: .top) {
                    if buzon.sinLeer > 0 {
                        Text(buzon.sinLeer > 99 ? "99+" : "\(buzon.sinLeer)")
                            .font(.caption2.weight(.bold)).monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Tema.Color.negativo, in: .capsule)
                            .offset(x: 14, y: -2)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(buzon.sinLeer > 0 ? "Mensajes, \(buzon.sinLeer) sin leer" : "Mensajes")
            boton("Cobro", icono: "eurosign.circle", acceso: .pago, id: "accesoPago")
                .accessibilityLabel("Registrar pago")
            boton("Incidencia", icono: "wrench.and.screwdriver", acceso: .incidencia, id: "accesoIncidencia")
                .accessibilityLabel("Nueva incidencia")
            boton("Gasto", icono: "cart", acceso: .gasto, id: "accesoGasto")
                .accessibilityLabel("Nuevo gasto")
        }
    }

    private func boton(_ titulo: String, icono: String, acceso: AccesoRapido, id: String) -> some View {
        Button { abierto = acceso } label: {
            VStack(spacing: 1) {
                Image(systemName: icono).font(.body.weight(.medium)).foregroundStyle(Tema.Color.primario)
                // Texto en el color principal: en azul sobre el cristal no llegaba al contraste mínimo.
                Text(titulo).font(.caption2.weight(.semibold)).foregroundStyle(Tema.Color.texto)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// Burbuja del asistente: un botón de cristal que se arrastra y se queda pegado al borde izquierdo
/// o derecho. Solo aparece si el asistente está activo y no se ha ocultado en Perfil; abre el chat
/// sabiendo qué piso o contrato está en pantalla.
struct BurbujaAsistente: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    let contexto: ContextoPantalla?
    let abrir: () -> Void

    @AppStorage("asistente.flotante") private var asistenteFlotante = true
    @AppStorage("burbuja.izquierda") private var izquierda = false
    /// Distancia al borde inferior del área segura.
    @AppStorage("burbuja.altura") private var altura = 150.0
    @State private var disponible = false
    @State private var arrastre: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            if disponible && asistenteFlotante {
                Button(action: abrir) {
                    Image(systemName: "sparkles").font(.title3.weight(.semibold)).frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tema.Color.primario)
                .fondoCristal(en: .circle)
                .accessibilityLabel(contexto.map { "Asistente, preguntar sobre \($0.descripcion)" } ?? "Asistente")
                .accessibilityHint("Arrástralo para moverlo a otro borde")
                .accessibilityIdentifier("burbujaAsistente")
                .padding(.horizontal, Tema.Espacio.s)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: izquierda ? .bottomLeading : .bottomTrailing)
                .padding(.bottom, altura)
                .offset(arrastre)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { arrastre = $0.translation }
                        .onEnded { fin in
                            withAnimation(reducirMovimiento ? nil : .snappy) {
                                izquierda = fin.predictedEndLocation.x < geo.size.width / 2
                                altura = min(max(altura - fin.translation.height, 80), max(geo.size.height - 120, 80))
                                arrastre = .zero
                            }
                        }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .task { disponible = (try? await sesion.api.enviar(.estadoAsistente))?.disponible ?? false }
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
