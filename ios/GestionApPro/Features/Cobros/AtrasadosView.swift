import SwiftUI

/// Cobros atrasados de meses anteriores (alerta roja de Inicio): mes, días de retraso y Registrar.
struct AtrasadosView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<[CobroAtrasado]> = .cargando
    @State private var registrando: CobroAtrasado?

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { lista in
            List {
                if lista.isEmpty {
                    EstadoVacio(icono: "checkmark.seal", titulo: "Sin cobros atrasados",
                                mensaje: "Todos los contratos tienen pagos en los meses anteriores.")
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(lista) { a in FilaAtrasado(atrasado: a) { registrando = a } }
                    } header: {
                        HStack {
                            Text(lista.count == 1 ? String(localized: "1 cobro atrasado") : String(localized: "\(lista.count) cobros atrasados"))
                            Spacer()
                            Text(Formato.euros(lista.reduce(Decimal(0)) { $0 + $1.importe })).monospacedDigit()
                        }
                    } footer: {
                        Text("Meses anteriores al actual en los que un contrato vigente no tuvo ningún pago. El retraso se cuenta desde el día 5.")
                    }
                    .filaLista()
                }
            }
            .estiloLista()
        }
        .navigationTitle("Cobros atrasados")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .datosCambiados)) { _ in Task { await cargar() } }
        .refreshable { await cargar() }
        .task { await cargar() }
        .hojaRegistrarAtrasado($registrando) { Task { await cargar() } }
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(.cobrosAtrasados())) }
        catch .noAutorizado {}
        catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) }
        }
    }
}

/// Fila de un cobro atrasado: inquilino, mes, días de retraso, importe y Registrar.
struct FilaAtrasado: View {
    let atrasado: CobroAtrasado
    let registrar: () -> Void
    @Environment(\.dynamicTypeSize) private var tamanoTexto

    var body: some View {
        let a = atrasado
        let disposicion = tamanoTexto.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Tema.Espacio.xs))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Tema.Espacio.s))
        disposicion {
            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                Text(a.inquilino.nombre).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                Text("\(a.etiquetaUnidad) · \(a.piso.direccion)")
                    .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                Label("\(a.mesTitulo) · \(a.diasRetraso) días de retraso", systemImage: "clock.badge.exclamationmark")
                    .font(Tema.Fuente.nota.weight(.semibold))
                    .foregroundStyle(Tema.Color.negativo)
            }
            if !tamanoTexto.isAccessibilitySize { Spacer(minLength: Tema.Espacio.xs) }
            VStack(alignment: tamanoTexto.isAccessibilitySize ? .leading : .trailing, spacing: Tema.Espacio.xs) {
                Text(Formato.euros(a.importe)).font(Tema.Fuente.cifraPequena).foregroundStyle(Tema.Color.texto).fixedSize()
                if a.contratoActivo {
                    Button("Registrar", action: registrar)
                        .buttonStyle(.borderedProminent)
                        .tint(Tema.Color.primarioRelleno)
                        .fixedSize()
                        .accessibilityLabel("Registrar pago de \(a.inquilino.nombre) de \(a.mesTitulo)")
                } else {
                    Text("Contrato finalizado").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                }
            }
        }
        .padding(.vertical, Tema.Espacio.xxs)
        .accessibilityElement(children: .contain)
        .contextMenu {
            if a.contratoActivo { Button("Registrar pago", systemImage: "eurosign.circle", action: registrar) }
            AccionesContacto(telefono: a.inquilino.telefono, email: a.inquilino.email)
        }
    }
}

extension View {
    /// Formulario de pago de un cobro atrasado, con la fecha dentro del mes que salda.
    func hojaRegistrarAtrasado(_ atrasado: Binding<CobroAtrasado?>, alGuardar: @escaping () -> Void) -> some View {
        sheet(item: atrasado) { a in
            PagoFormView(idContrato: a.idContrato, importe: a.importe, fechaInicial: a.fechaParaSaldar,
                         notaFecha: String(localized: "La fecha propuesta es del mes que salda (\(a.mesTitulo)); los cobros se cuentan por la fecha del pago.")) { _ in
                NotificationCenter.default.post(name: .datosCambiados, object: nil)
                alGuardar()
            }
        }
    }
}
