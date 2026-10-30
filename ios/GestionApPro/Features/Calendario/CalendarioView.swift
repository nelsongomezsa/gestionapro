import SwiftUI

/// Calendario mensual de cobros y vencimientos (CalendarioController del escritorio).
struct CalendarioView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var mes = Mes.actual
    @State private var estado: EstadoCarga<Calendario> = .cargando
    @State private var diaElegido: Calendario.Dia?

    private let columnas = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let diasSemana = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { cal in
            ScrollView {
                VStack(spacing: Tema.Espacio.l) {
                    SelectorMes(mes: mes) { nuevo in mes = nuevo; Task { await cargar(reiniciar: true) } }

                    HStack(spacing: Tema.Espacio.s) {
                        totalCelda("Esperado", cal.esperado, .neutro)
                        totalCelda("Cobrado", cal.cobrado, .positivo)
                        totalCelda("Pendiente", cal.pendiente, cal.pendiente > 0 ? .negativo : .neutro)
                    }

                    VStack(spacing: Tema.Espacio.xs) {
                        LazyVGrid(columns: columnas, spacing: 6) {
                            ForEach(diasSemana, id: \.self) { Text($0).estiloEtiqueta() }
                            ForEach(0..<cal.huecosIniciales, id: \.self) { _ in Color.clear.frame(height: 48) }
                            ForEach(cal.dias) { dia in
                                Button { diaElegido = dia } label: { CeldaDia(dia: dia) }
                                    .buttonStyle(.plain)
                            }
                        }
                        Leyenda().padding(.top, Tema.Espacio.xs)
                    }
                    .tarjeta()
                }
                .padding(Tema.Espacio.m)
            }
            .background(Tema.Color.fondo)
        }
        .navigationTitle("Calendario")
        .refreshable { await cargar() }
        .task { await cargar() }
        .sheet(item: $diaElegido) { DetalleDiaView(dia: $0).presentationDetents([.medium, .large]) }
    }

    private func totalCelda(_ titulo: String, _ importe: Decimal, _ tono: Tono) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
            Text(titulo).estiloEtiqueta()
            Text(Formato.euros(importe)).font(Tema.Fuente.cifraPequena).foregroundStyle(tono == .neutro ? .primary : tono.color)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .tarjeta(relleno: Tema.Espacio.s)
    }

    private func cargar(reiniciar: Bool = false) async {
        if reiniciar || estado.valor == nil { estado = .cargando }
        do { estado = .cargado(try await sesion.api.enviar(.calendario(mes: mes))) }
        catch .noAutorizado {}
        catch { estado = .error(error.localizedDescription) }
    }
}

private struct CeldaDia: View {
    let dia: Calendario.Dia

    private var numero: Int { Calendar(identifier: .gregorian).component(.day, from: dia.fecha) }
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
        VStack(spacing: 3) {
            Text("\(numero)").font(.subheadline.weight(esHoy ? .bold : .regular)).monospacedDigit()
            HStack(spacing: Tema.Espacio.linea) {
                if !dia.pagos.isEmpty { Circle().fill(Tema.Color.positivo).frame(width: 5, height: 5) }
                if !dia.vencimientos.isEmpty { Circle().fill(Tema.Color.aviso).frame(width: 5, height: 5) }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background((tono?.color ?? .clear).opacity(0.16), in: .rect(cornerRadius: Tema.Radio.pequeno))
        .overlay {
            RoundedRectangle(cornerRadius: Tema.Radio.pequeno)
                .strokeBorder(esHoy ? Tema.Color.primario : (dia.estado == .esperado ? Tema.Color.primario.opacity(0.5) : .clear),
                              lineWidth: esHoy ? 2 : 1)
        }
        .foregroundStyle(tono?.color ?? .primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(etiquetaAccesible)
    }

    private var etiquetaAccesible: String {
        var partes = [dia.fecha.formatted(.dateTime.day().month(.wide).locale(Formato.locale))]
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
        HStack(spacing: Tema.Espacio.s) {
            item("Pagado", Tema.Color.positivo)
            item("Esperado (días 1-5)", Tema.Color.primario)
            item("Vencido sin cobrar", Tema.Color.negativo)
            item("Fin de contrato", Tema.Color.aviso, punto: true)
        }
        .font(.caption2)
        .foregroundStyle(Tema.Color.textoSecundario)
    }

    private func item(_ texto: String, _ color: Color, punto: Bool = false) -> some View {
        HStack(spacing: 3) {
            if punto { Circle().fill(color).frame(width: 6, height: 6) } else {
                RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.35)).frame(width: 10, height: 10)
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
                Section("Pagos") {
                    if dia.pagos.isEmpty { Text("Sin pagos este día").foregroundStyle(Tema.Color.textoSecundario) }
                    ForEach(dia.pagos) { FilaPago(pago: $0) }
                    if !dia.pagos.isEmpty {
                        LabeledContent("Total", value: Formato.euros(dia.pagos.reduce(0) { $0 + $1.cantidad }))
                            .font(Tema.Fuente.subtitulo)
                    }
                }
                Section("Terminan este día") {
                    if dia.vencimientos.isEmpty { Text("Ningún contrato").foregroundStyle(Tema.Color.textoSecundario) }
                    ForEach(dia.vencimientos) { FilaContratoCompleto(contrato: $0) }
                }
                if dia.estado == .vencido || dia.estado == .esperado {
                    Section {
                        Label(dia.estado == .vencido ? "Día de cobro pasado con contratos aún sin pagar este mes"
                                                     : "Día de cobro habitual (del 1 al 5)",
                              systemImage: "info.circle")
                            .font(Tema.Fuente.detalle)
                    }
                }
            }
            .navigationTitle(dia.fecha.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Formato.locale)).capitalized(with: Formato.locale))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
