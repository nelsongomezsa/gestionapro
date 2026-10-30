import SwiftUI

/// Calendario mensual de cobros y vencimientos (CalendarioController del escritorio).
struct CalendarioView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var mes = Mes.actual
    @State private var estado: EstadoCarga<Calendario> = .cargando
    @State private var diaElegido: Calendario.Dia?

    private let columnas = Array(repeating: GridItem(.flexible(), spacing: Tema.Espacio.xxs), count: 7)
    private let diasSemana = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { cal in
            ScrollView {
                VStack(spacing: Tema.Espacio.l) {
                    SelectorMes(mes: mes) { nuevo in mes = nuevo; Task { await cargar(reiniciar: true) } }

                    ResumenCobros(nombreMes: cal.nombreMes, cobrado: cal.cobrado, esperado: cal.esperado, pendiente: cal.pendiente)

                    VStack(spacing: Tema.Espacio.s) {
                        LazyVGrid(columns: columnas, spacing: Tema.Espacio.xxs) {
                            ForEach(diasSemana, id: \.self) { Text($0).estiloEtiqueta().accessibilityHidden(true) }
                            ForEach(0..<cal.huecosIniciales, id: \.self) { _ in Color.clear.frame(height: Tema.Tamano.celdaCalendario) }
                            ForEach(cal.dias) { dia in
                                Button { diaElegido = dia } label: { CeldaDia(dia: dia) }
                                    .buttonStyle(.plain)
                            }
                        }
                        Leyenda().padding(.top, Tema.Espacio.xxs)
                    }
                    .tarjeta()
                }
                .padding(.horizontal, Tema.Espacio.m)
                .padding(.bottom, Tema.Espacio.l)
            }
            .background(Tema.Color.fondo)
        }
        .background(Tema.Color.fondo)
        .navigationTitle("Calendario")
        .refreshable { await cargar() }
        .task { await cargar() }
        .sheet(item: $diaElegido) { DetalleDiaView(dia: $0).presentationDetents([.medium, .large]) }
    }

    private func cargar(reiniciar: Bool = false) async {
        if reiniciar || estado.valor == nil { estado = .cargando }
        let pedido = mes
        do {
            let cal = try await sesion.api.enviar(.calendario(mes: pedido))
            // Si se cambió de mes mientras cargaba, esta respuesta ya no vale.
            guard pedido == mes else { return }
            estado = .cargado(cal)
        }
        catch .noAutorizado {}
        catch { estado = .error(error.localizedDescription) }
    }
}

private struct CeldaDia: View {
    let dia: Calendario.Dia

    /// Misma zona que los huecos iniciales y "hoy", para que el número no se desplace un día.
    private var numero: Int {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return c.component(.day, from: dia.fecha)
    }
    private var esHoy: Bool {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return c.isDateInToday(dia.fecha)
    }

    private var tono: Tono? {
        switch dia.estado {
        case .pagado: .positivo
        case .vencido: .negativo
        case .esperado: .primario
        case .normal: nil
        }
    }

    var body: some View {
        VStack(spacing: Tema.Espacio.xxs) {
            Text("\(numero)").font(Tema.Fuente.detalle.weight(esHoy ? .bold : .regular)).monospacedDigit()
            HStack(spacing: Tema.Espacio.linea) {
                if !dia.pagos.isEmpty { Circle().fill(Tema.Color.positivo).frame(width: Tema.Tamano.punto, height: Tema.Tamano.punto) }
                if !dia.vencimientos.isEmpty { Circle().fill(Tema.Color.aviso).frame(width: Tema.Tamano.punto, height: Tema.Tamano.punto) }
            }
            .frame(height: Tema.Tamano.punto)
        }
        .frame(maxWidth: .infinity, minHeight: Tema.Tamano.celdaCalendario)
        .background((tono?.color ?? .clear).opacity(0.16), in: .rect(cornerRadius: Tema.Radio.pequeno))
        .overlay {
            RoundedRectangle(cornerRadius: Tema.Radio.pequeno)
                .strokeBorder(esHoy ? Tema.Color.primario : (dia.estado == .esperado ? Tema.Color.primario.opacity(0.5) : .clear),
                              lineWidth: esHoy ? 2 : 1)
        }
        .foregroundStyle(tono?.color ?? Tema.Color.texto)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etiquetaAccesible)
    }

    private var etiquetaAccesible: String {
        var partes = [dia.fecha.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Formato.locale))]
        switch dia.estado {
        case .pagado: partes.append("\(dia.pagos.count) pagos")
        case .vencido: partes.append("cobro vencido sin pagar")
        case .esperado: partes.append("cobro esperado")
        case .normal: break
        }
        if !dia.vencimientos.isEmpty { partes.append("\(dia.vencimientos.count) contratos terminan") }
        return partes.joined(separator: ", ")
    }
}

private struct Leyenda: View {
    var body: some View {
        // Dos columnas: en una sola fila no cabía y se cortaba.
        Grid(alignment: .leading, horizontalSpacing: Tema.Espacio.m, verticalSpacing: Tema.Espacio.xs) {
            GridRow {
                item("Pagado", Tema.Color.positivo)
                item("Cobro esperado (días 1-5)", Tema.Color.primario)
            }
            GridRow {
                item("Vencido sin cobrar", Tema.Color.negativo)
                item("Fin de contrato", Tema.Color.aviso, punto: true)
            }
        }
        .font(Tema.Fuente.nota)
        .foregroundStyle(Tema.Color.textoSecundario)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func item(_ texto: String, _ color: Color, punto: Bool = false) -> some View {
        HStack(spacing: Tema.Espacio.xxs) {
            if punto { Circle().fill(color).frame(width: Tema.Tamano.punto, height: Tema.Tamano.punto) } else {
                RoundedRectangle(cornerRadius: Tema.Radio.pequeno / 4).fill(color.opacity(0.35))
                    .frame(width: Tema.Tamano.punto * 1.5, height: Tema.Tamano.punto * 1.5)
            }
            Text(texto)
        }
    }
}

/// Detalle de un día: pagos y contratos que terminan.
struct DetalleDiaView: View {
    let dia: Calendario.Dia

    var body: some View {
        NavigationStack {
            List {
                // Secciones vacías ocultas; si no hay nada, un único mensaje.
                if dia.pagos.isEmpty && dia.vencimientos.isEmpty {
                    Section { Text("Sin pagos ni fines de contrato este día").foregroundStyle(Tema.Color.textoSecundario) }
                        .filaLista()
                }
                if !dia.pagos.isEmpty {
                    Section("Pagos") {
                        ForEach(dia.pagos) { FilaPago(pago: $0) }
                        LabeledContent("Total", value: Formato.euros(dia.pagos.reduce(0) { $0 + $1.cantidad }))
                            .font(Tema.Fuente.subtitulo)
                    }
                    .filaLista()
                }
                if !dia.vencimientos.isEmpty {
                    Section("Terminan este día") {
                        ForEach(dia.vencimientos) { FilaContratoCompleto(contrato: $0) }
                    }
                    .filaLista()
                }
                if dia.estado == .vencido || dia.estado == .esperado {
                    Section {
                        Label(dia.estado == .vencido ? "Día de cobro pasado con contratos aún sin pagar este mes"
                                                     : "Día de cobro habitual (del 1 al 5)",
                              systemImage: "info.circle")
                            .font(Tema.Fuente.detalle)
                    }
                    .filaLista()
                }
            }
            .estiloLista()
            .navigationTitle(Formato.primeraMayuscula(dia.fecha.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Formato.locale))))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
