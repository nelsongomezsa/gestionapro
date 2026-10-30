import SwiftUI

/// Ficha del inquilino: contacto, contrato activo, historial, pagos, QR de pago e invitación.
struct InquilinoFichaView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.openURL) private var abrirURL
    let id: Int
    var alCambiar: () -> Void = {}

    @State private var estado: EstadoCarga<Inquilino> = .cargando
    @State private var editando = false
    @State private var contactando = false
    @State private var compartir: Compartible?
    @State private var qr: QrPago?
    @State private var invitacion: Invitacion?
    @State private var trabajando = false
    @State private var error: String?

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { i in
            List {
                cabecera(i)
                if let c = i.contratoActivo {
                    Section("Contrato activo") { FilaContrato(contrato: c) }
                    .filaLista()
                }
                Section("Datos") {
                    LabeledContent("DNI", value: i.dni)
                    LabeledContent("Teléfono", value: i.telefono ?? "—")
                    LabeledContent("Email", value: i.email ?? "—")
                }
                .filaLista()
                Section {
                    Button { Task { await pedirQr(i) } } label: {
                        Label("QR de pago del mes", systemImage: "qrcode")
                    }
                    .disabled(i.contratoActivo == nil || trabajando)
                    if !i.tieneCuentaApp {
                        Button { Task { await invitar(i) } } label: {
                            Label("Invitar a la app", systemImage: "iphone.and.arrow.forward")
                        }
                        .disabled(trabajando)
                    } else {
                        Label("Ya usa la app", systemImage: "checkmark.circle.fill").foregroundStyle(Tema.Color.positivo)
                    }
                } header: {
                    Text("Acciones")
                } footer: {
                    if i.contratoActivo == nil { Text("El QR de pago necesita un contrato activo.") }
                }
                .filaLista()
                let historico = i.contratos.filter { !$0.activo }
                if !historico.isEmpty {
                    Section("Contratos anteriores") { ForEach(historico) { FilaContrato(contrato: $0) } }
                    .filaLista()
                }
                Section("Últimos pagos") {
                    if i.pagos.isEmpty {
                        Text("Sin pagos registrados").foregroundStyle(Tema.Color.textoSecundario)
                    } else {
                        ForEach(i.pagos) { p in
                            FilaMetrica(titulo: p.fechaPago.formatted(.dateTime.day().month(.wide).year().locale(Formato.locale)),
                                        valor: Formato.euros(p.cantidad), nota: p.metodoPago.nombre)
                        }
                    }
                }
                .filaLista()
            }
            .estiloLista()
            // El nombre ya va grande en la cabecera.
            .navigationTitle("Inquilino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Editar") { editando = true } } }
            .sheet(isPresented: $editando) {
                InquilinoFormView(inquilino: i) { _ in Task { await cargar(); alCambiar() } }
            }
            .confirmationDialog("Contactar con \(i.nombre)", isPresented: $contactando, titleVisibility: .visible) {
                if let tel = i.telefono, let url = Contacto.llamada(tel) { Button("Llamar") { abrirURL(url) } }
                if let tel = i.telefono, let url = Contacto.whatsApp(tel) { Button("WhatsApp") { abrirURL(url) } }
                if let email = i.email, let url = Contacto.email(email) { Button("Email") { abrirURL(url) } }
                Button("Compartir contacto…") {
                    compartir = Compartible(elementos: [Contacto.vCard(nombre: i.nombre, apellidos: i.apellidos,
                                                                       telefono: i.telefono, email: i.email)])
                }
            }
        }
        .task { await cargar() }
        .refreshable { await cargar() }
        .hojaCompartir($compartir)
        .sheet(item: Binding(get: { qr.map(QrIdentificable.init) }, set: { qr = $0?.qr })) { QrPagoView(qr: $0.qr) }
        .sheet(item: Binding(get: { invitacion.map(InvitacionIdentificable.init) }, set: { invitacion = $0?.invitacion })) {
            InvitacionView(invitacion: $0.invitacion)
        }
        .alertaError($error)
    }

    private func cabecera(_ i: Inquilino) -> some View {
        Section {
            VStack(spacing: Tema.Espacio.s) {
                AvatarIniciales(nombre: i.nombreCompleto, tamano: Tema.Tamano.avatarGrande)
                Text(i.nombreCompleto)
                    .font(Tema.Fuente.titulo)
                    .foregroundStyle(Tema.Color.texto)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: Tema.Espacio.l) {
                    accionContacto("Llamar", icono: "phone.fill", habilitado: i.telefono != nil) {
                        if let t = i.telefono, let url = Contacto.llamada(t) { abrirURL(url) }
                    }
                    accionContacto("Mensaje", icono: "message.fill", habilitado: i.telefono != nil) {
                        if let t = i.telefono, let url = Contacto.whatsApp(t) { abrirURL(url) }
                    }
                    accionContacto("Email", icono: "envelope.fill", habilitado: i.email != nil) {
                        if let e = i.email, let url = Contacto.email(e) { abrirURL(url) }
                    }
                    accionContacto("Más", icono: "square.and.arrow.up", habilitado: true) { contactando = true }
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
        .filaLista()
    }

    private func accionContacto(_ titulo: String, icono: String, habilitado: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            VStack(spacing: Tema.Espacio.xxs) {
                Image(systemName: icono)
                    .frame(width: Tema.Tamano.botonRedondo, height: Tema.Tamano.botonRedondo)
                    .background(Tema.Color.primarioSuave, in: .circle)
                Text(titulo).font(Tema.Fuente.nota)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(habilitado ? Tema.Color.primario : Tema.Color.textoSecundario)
        .disabled(!habilitado)
    }

    private func cargar() async {
        do {
            estado = .cargado(try await sesion.api.enviar(.inquilino(id: id)))
        } catch .noAutorizado {
        } catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) } else { self.error = error.localizedDescription }
        }
    }

    private func pedirQr(_ i: Inquilino) async {
        trabajando = true
        defer { trabajando = false }
        do { qr = try await sesion.api.enviar(.qrPago(inquilino: i.id)) } catch .noAutorizado {} catch { self.error = error.localizedDescription }
    }

    private func invitar(_ i: Inquilino) async {
        trabajando = true
        defer { trabajando = false }
        do { invitacion = try await sesion.api.enviar(.invitar(inquilino: i.id)) } catch .noAutorizado {} catch { self.error = error.localizedDescription }
    }
}

struct FilaContrato: View {
    let contrato: ContratoBreve

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
            HStack {
                Text("Hab. \(contrato.numeroHabitacion) · \(contrato.piso.direccion)")
                    .font(Tema.Fuente.subtitulo)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text(Formato.euros(contrato.precioMensual)).font(Tema.Fuente.cifraPequena)
            }
            HStack {
                Text(rango).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                Spacer()
                InsigniaEstado(texto: contrato.activo ? contrato.vencimiento.estadoCorto : "Finalizado",
                               tono: contrato.activo ? contrato.vencimiento.tono : .neutro)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var rango: String {
        let f = Date.FormatStyle.dateTime.day().month(.abbreviated).year().locale(Formato.locale)
        return "\(contrato.fechaInicio.formatted(f)) – \(contrato.fechaFin.formatted(f))"
    }
}

private struct QrIdentificable: Identifiable {
    let qr: QrPago
    var id: String { qr.payload }
}

private struct InvitacionIdentificable: Identifiable {
    let invitacion: Invitacion
    var id: String { invitacion.codigo }
}
