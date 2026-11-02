import SwiftUI

/// Análisis guardados: abrir uno en la calculadora, borrarlo o elegir 2 o 3 para compararlos.
struct AnalisisGuardadosView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    /// Abre el análisis en la calculadora de la que se vino.
    let abrir: (AnalisisGuardado) -> Void
    @State private var estado: EstadoCarga<[AnalisisGuardado]> = .cargando
    @State private var elegidos: [Int] = []
    @State private var comparando = false
    @State private var paraBorrar: AnalisisGuardado?
    @State private var error: String?

    static let maximoComparar = 3

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { lista in
            List {
                if lista.isEmpty {
                    EstadoVacio(icono: "square.stack.3d.up", titulo: "Sin análisis guardados",
                                mensaje: "En la calculadora, pulsa Guardar para conservar una simulación y compararla después.")
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(lista) { a in
                            FilaAnalisis(analisis: a, elegido: elegidos.contains(a.id),
                                         puedeElegir: elegidos.count < Self.maximoComparar || elegidos.contains(a.id),
                                         alternar: { alternar(a.id) }) {
                                abrir(a)
                                cerrar()
                            }
                            .swipeActions { Button("Borrar", systemImage: "trash", role: .destructive) { paraBorrar = a } }
                        }
                    } header: {
                        Text("\(lista.count) análisis")
                    } footer: {
                        Text("Marca 2 o 3 para compararlos lado a lado. Toca uno para abrirlo en la calculadora.")
                    }
                    .filaLista()
                }
            }
            .estiloLista()
            .safeAreaInset(edge: .bottom) {
                if elegidos.count >= 2 {
                    BotonPrincipal(titulo: String(localized: "Comparar \(elegidos.count)"), icono: "rectangle.split.3x1") {
                        comparando = true
                    }
                    .accessibilityIdentifier("comparar")
                    .padding(.horizontal, Tema.Espacio.m)
                    .padding(.bottom, 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(Tema.Movimiento.suave, value: elegidos.count >= 2)
            .navigationDestination(isPresented: $comparando) {
                ComparacionAnalisisView(analisis: elegidos.compactMap { id in lista.first { $0.id == id } })
            }
        }
        .navigationTitle("Análisis guardados")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await cargar() }
        .task { await cargar() }
        .confirmationDialog("¿Borrar «\(paraBorrar?.nombre ?? "")»?", isPresented: Binding(
            get: { paraBorrar != nil }, set: { if !$0 { paraBorrar = nil } }), titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { if let a = paraBorrar { Task { await borrar(a) } } }
        }
        .alertaError($error)
    }

    private func alternar(_ id: Int) {
        if let i = elegidos.firstIndex(of: id) { elegidos.remove(at: i) }
        else if elegidos.count < Self.maximoComparar { elegidos.append(id) }
    }

    private func cargar() async {
        do {
            let lista = try await sesion.api.enviar(.analisisGuardados)
            estado = .cargado(lista)
            elegidos.removeAll { id in !lista.contains { $0.id == id } }
        } catch .noAutorizado {
        } catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) } else { self.error = error.localizedDescription }
        }
    }

    private func borrar(_ a: AnalisisGuardado) async {
        do {
            _ = try await sesion.api.enviar(.borrarAnalisis(id: a.id))
            Haptica.impacto()
            await cargar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct FilaAnalisis: View {
    let analisis: AnalisisGuardado
    let elegido: Bool
    let puedeElegir: Bool
    let alternar: () -> Void
    let abrir: () -> Void

    var body: some View {
        let a = analisis
        HStack(spacing: Tema.Espacio.s) {
            Button(action: alternar) {
                Image(systemName: elegido ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(elegido ? Tema.Color.primario : Tema.Color.textoSecundario)
                    .frame(width: Tema.Tamano.botonRedondo, height: Tema.Tamano.botonRedondo)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(!puedeElegir)
            .sensoryFeedback(.selection, trigger: elegido)
            .accessibilityLabel(elegido ? Text("Quitar de la comparación") : Text("Añadir a la comparación"))
            .accessibilityIdentifier("elegirAnalisis")

            Button(action: abrir) {
                HStack(spacing: Tema.Espacio.s) {
                    VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                        Text(a.nombre).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                        Text("\(Formato.euros(a.entrada.precioCompra)) · \(Formato.euros(a.entrada.alquilerMensual)) al mes")
                            .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                        Text(a.fecha, format: .relative(presentation: .named).locale(Formato.localeFechas))
                            .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    }
                    Spacer(minLength: Tema.Espacio.xs)
                    if let r = a.resultado {
                        VStack(alignment: .trailing, spacing: Tema.Espacio.linea) {
                            Text(Formato.porcentaje(r.rentabilidadNetaPct)).font(Tema.Fuente.cifraPequena)
                                .foregroundStyle(Tono.signo(r.rentabilidadNetaPct.double).color)
                            Text("neta").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                        }
                    }
                    ChevronTocable()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Abre el análisis en la calculadora")
        }
    }
}

/// 2 o 3 análisis lado a lado; en cada fila, el mejor valor resaltado.
struct ComparacionAnalisisView: View {
    let analisis: [AnalisisGuardado]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                ForEach(ComparacionAnalisis.grupos, id: \.titulo) { grupo in
                    SeccionTarjeta(titulo: grupo.titulo) {
                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Tema.Espacio.s, verticalSpacing: Tema.Espacio.s) {
                            GridRow {
                                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                                ForEach(analisis) { a in
                                    Text(a.nombre).font(Tema.Fuente.nota.weight(.semibold)).foregroundStyle(Tema.Color.primario)
                                        .lineLimit(3).frame(maxWidth: .infinity, alignment: .trailing)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                            ForEach(grupo.filas, id: \.titulo) { fila in
                                Divider().overlay(Tema.Color.borde)
                                let valores = analisis.map { fila.valor($0) }
                                let mejor = ComparacionAnalisis.mejor(valores, mayorEsMejor: fila.mayorEsMejor)
                                GridRow {
                                    Text(fila.titulo).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.texto)
                                        .fixedSize(horizontal: false, vertical: true)
                                    ForEach(Array(valores.enumerated()), id: \.offset) { i, v in
                                        Text(v.map(fila.formato) ?? "—")
                                            .font(Tema.Fuente.cifraPequena)
                                            .foregroundStyle(i == mejor ? Tema.Color.positivo : Tema.Color.texto)
                                            .minimumScaleFactor(0.7).lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            .accessibilityLabel("\(analisis[i].nombre), \(fila.titulo): "
                                                + (v.map(fila.formato) ?? String(localized: "sin dato"))
                                                + (i == mejor ? String(localized: ", el mejor") : ""))
                                    }
                                }
                            }
                        }
                    }
                }
                Text("En verde, el mejor valor de cada fila.").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
            .padding(.horizontal, Tema.Espacio.m)
            .padding(.bottom, Tema.Espacio.l)
        }
        .background(Tema.Color.fondo)
        .navigationTitle("Comparar análisis")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Filas de la comparación y cuál es la mejor (sin vista, para probarlo).
enum ComparacionAnalisis {
    struct Fila {
        let titulo: String
        let valor: (AnalisisGuardado) -> Double?
        /// nil: no se compara (datos de partida).
        let mayorEsMejor: Bool?
        let formato: (Double) -> String
    }

    struct Grupo {
        let titulo: String
        let filas: [Fila]
    }

    private static func euros(_ v: Double) -> String { Formato.euros(v) }
    private static func pct(_ v: Double) -> String { Formato.porcentaje(v) }

    static var grupos: [Grupo] {
        [
            Grupo(titulo: String(localized: "Rentabilidad"), filas: [
                Fila(titulo: String(localized: "Rentabilidad bruta"), valor: { $0.resultado?.rentabilidadBrutaPct.double }, mayorEsMejor: true, formato: pct),
                Fila(titulo: String(localized: "Rentabilidad neta"), valor: { $0.resultado?.rentabilidadNetaPct.double }, mayorEsMejor: true, formato: pct),
                Fila(titulo: String(localized: "Cash flow al mes"), valor: { $0.resultado?.cashFlowMensual.double }, mayorEsMejor: true, formato: euros),
                Fila(titulo: String(localized: "Años para recuperarla"), valor: { $0.resultado?.aniosRecuperacion?.double }, mayorEsMejor: false,
                     formato: { Formato.anios($0) }),
                Fila(titulo: String(localized: "Plusvalía a 10 años"), valor: { $0.resultado?.plusvalia10Anios?.double }, mayorEsMejor: true, formato: euros),
            ]),
            Grupo(titulo: String(localized: "Inversión"), filas: [
                Fila(titulo: String(localized: "Precio de compra"), valor: { $0.entrada.precioCompra }, mayorEsMejor: nil, formato: euros),
                Fila(titulo: String(localized: "Inversión total"), valor: { $0.resultado?.totalCompra.double }, mayorEsMejor: false, formato: euros),
                Fila(titulo: String(localized: "Capital aportado"), valor: { $0.resultado?.capitalAportado.double }, mayorEsMejor: false, formato: euros),
                Fila(titulo: String(localized: "Cuota de hipoteca"), valor: { $0.resultado?.cuotaMensual.double }, mayorEsMejor: false, formato: euros),
            ]),
            Grupo(titulo: String(localized: "Ingresos y gastos"), filas: [
                Fila(titulo: String(localized: "Alquiler mensual"), valor: { $0.entrada.alquilerMensual }, mayorEsMejor: true, formato: euros),
                Fila(titulo: String(localized: "Gastos al mes"), valor: { $0.resultado?.gastosMensuales.double }, mayorEsMejor: false, formato: euros),
            ]),
        ]
    }

    /// Índice del mejor valor; nil si no se compara, faltan datos o todos son iguales.
    static func mejor(_ valores: [Double?], mayorEsMejor: Bool?) -> Int? {
        guard let mayorEsMejor else { return nil }
        let conDato = valores.enumerated().compactMap { i, v in v.map { (i, $0) } }
        guard conDato.count >= 2, Set(conDato.map(\.1)).count > 1 else { return nil }
        return (mayorEsMejor ? conDato.max { $0.1 < $1.1 } : conDato.min { $0.1 < $1.1 })?.0
    }
}
