import SwiftUI

/// QR de pago SEPA del mes: se muestra para escanear desde la app del banco y se puede compartir.
struct QrPagoView: View {
    let qr: QrPago
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Tema.Espacio.l) {
                    if let imagen = CodigoQR.imagen(de: qr.payload) {
                        Image(uiImage: imagen)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 260)
                            .padding(Tema.Espacio.m)
                            .background(.white, in: .rect(cornerRadius: Tema.Radio.grande))
                            .accessibilityLabel("Código QR de pago de \(Formato.euros(qr.importe))")
                    }
                    Text(Formato.euros(qr.importe)).font(Tema.Fuente.cifraGrande)
                    VStack(spacing: Tema.Espacio.s) {
                        FilaMetrica(titulo: "Beneficiario", valor: qr.beneficiario)
                        Divider()
                        FilaMetrica(titulo: "IBAN", valor: qr.iban)
                        Divider()
                        FilaMetrica(titulo: "Concepto", valor: qr.concepto)
                    }
                    .tarjeta()
                    Text("Escanéalo desde la app del banco para pagar por transferencia SEPA.")
                        .font(Tema.Fuente.nota)
                        .foregroundStyle(Tema.Color.textoSecundario)
                        .multilineTextAlignment(.center)
                }
                .padding(Tema.Espacio.l)
            }
            .background(Tema.Color.fondo)
            .navigationTitle("QR de pago")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { cerrar() } }
                if let imagen = CodigoQR.imagen(de: qr.payload) {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: Image(uiImage: imagen),
                                  message: Text("\(qr.concepto): \(Formato.euros(qr.importe)) a \(qr.beneficiario), IBAN \(qr.iban)"),
                                  preview: SharePreview("QR de pago", image: Image(uiImage: imagen))) {
                            Label("Compartir", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }
}

/// Código de invitación recién generado, para compartir con el inquilino.
struct InvitacionView: View {
    let invitacion: Invitacion
    @Environment(\.dismiss) private var cerrar

    private var mensaje: String {
        "Te invito a GestionAp. Descarga la app y regístrate con este código: \(invitacion.codigo) "
            + "(caduca el \(invitacion.expira.formatted(.dateTime.day().month(.wide).locale(Formato.locale))))."
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Tema.Espacio.l) {
                Image(systemName: "envelope.open.badge.clock").font(.system(size: 48)).foregroundStyle(Tema.Color.primario)
                Text("Código de invitación").font(Tema.Fuente.titulo)
                Text(invitacion.codigo)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .textSelection(.enabled)
                    .padding()
                    .tarjeta()
                Text("Es de un solo uso y caduca en 7 días. Solo se muestra ahora: compártelo con el inquilino.")
                    .font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario).multilineTextAlignment(.center)
                if invitacion.emailEnviado {
                    Label("También se le ha enviado por email", systemImage: "checkmark.circle").foregroundStyle(Tema.Color.positivo)
                }
                ShareLink(item: mensaje) {
                    Label("Compartir invitación", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Tema.Color.primarioRelleno)
                .controlSize(.large)
            }
            .padding(Tema.Espacio.l)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { cerrar() } } }
        }
    }
}
