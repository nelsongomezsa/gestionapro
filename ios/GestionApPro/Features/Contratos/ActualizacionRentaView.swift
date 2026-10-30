import SwiftUI

/// Estado de la actualización de renta de un contrato. Lo guarda la pantalla, como el de la fianza.
@MainActor @Observable
final class ModeloRenta {
    var propuesta: PropuestaRenta?
    var historial: [HistorialRenta] = []
    var revisando = false
    var error: String?

    func cargar(contrato id: Int, gestor: Bool, con api: APIClient) async {
        do {
            historial = try await api.enviar(.historialRenta(contrato: id))
            if gestor { propuesta = try await api.enviar(.propuestaRenta(contrato: id)) }
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// "+2,54 %"
private func conSigno(_ pct: Decimal) -> String {
    (pct > 0 ? "+" : "") + Formato.porcentaje(pct)
}

/// "septiembre de 2026" a partir de "2026-09".
func nombreMes(_ periodo: String?) -> String? {
    guard let periodo, let fecha = try? Date(periodo + "-15", strategy: .iso8601.year().month().day()) else { return nil }
    return fecha.formatted(.dateTime.month(.wide).year().locale(Formato.locale))
}

/// Sección "Actualización de renta": propuesta (propietario) e historial (también el inquilino).
struct SeccionRenta: View {
    let modelo: ModeloRenta
    var gestor = false

    var body: some View {
        if gestor || !modelo.historial.isEmpty {
            Section {
                if gestor, let p = modelo.propuesta {
                    if p.debida, let fecha = p.fechaEfecto {
                        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                            Text("Toca actualizar el \(fecha.formatted(FormatoFecha.larga))")
                                .font(Tema.Fuente.subtitulo)
                            if let pct = p.porcentaje, let nueva = p.rentaNueva {
                                Text("\(p.indice.nombre) \(conSigno(pct)): \(Formato.euros(p.rentaActual)) → \(Formato.euros(nueva))")
                                    .font(Tema.Fuente.detalle).monospacedDigit()
                                    .foregroundStyle(Tema.Color.textoSecundario)
                            }
                        }
                        Button { modelo.revisando = true } label: {
                            Label("Revisar y aplicar", systemImage: "arrow.up.right.circle")
                        }
                        .accessibilityIdentifier("botonActualizarRenta")
                    } else if let fecha = p.fechaEfecto {
                        FilaMetrica(titulo: "Próxima actualización", valor: fecha.formatted(FormatoFecha.corta),
                                    nota: "Índice recomendado: \(p.indiceRecomendado.nombre)")
                    } else {
                        Text(p.aviso).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                    }
                }
                ForEach(modelo.historial) { h in
                    FilaMetrica(titulo: h.fechaEfecto.formatted(FormatoFecha.corta),
                                valor: Formato.euros(h.rentaNueva),
                                nota: "\(h.indice.nombre) \(conSigno(h.porcentaje)) · antes \(Formato.euros(h.rentaAnterior))")
                }
            } header: {
                Text("Actualización de renta")
            }
            .filaLista()
        }
    }
}

extension View {
    /// Carga la propuesta y el historial y presenta la revisión; se pone en la pantalla, fuera de la List.
    func actualizacionRenta(_ modelo: ModeloRenta, contrato id: Int?, gestor: Bool, api: APIClient,
                            alAplicar: @escaping () async -> Void = {}) -> some View {
        @Bindable var modelo = modelo
        return self
            .task(id: id) { if let id { await modelo.cargar(contrato: id, gestor: gestor, con: api) } }
            .sheet(isPresented: $modelo.revisando) {
                if let id, let p = modelo.propuesta {
                    NavigationStack {
                        RevisionRentaView(idContrato: id, inicial: p) { _ in
                            await modelo.cargar(contrato: id, gestor: gestor, con: api)
                            await alAplicar()
                        }
                    }
                }
            }
            .alertaError($modelo.error)
    }
}

/// Revisión antes de aplicar: índice (el recomendado por defecto), dato del INE con su fuente y confirmación.
struct RevisionRentaView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let idContrato: Int
    let inicial: PropuestaRenta
    let alAplicar: (HistorialRenta) async -> Void

    @State private var propuesta: PropuestaRenta?
    @State private var indice: IndiceRenta = .irav
    @State private var manual: Decimal?
    @State private var aplicando = false
    @State private var error: String?

    private var actual: PropuestaRenta { propuesta ?? inicial }
    /// Porcentaje que se aplicará: el que se escribe (relleno con el máximo). Nunca más que el máximo.
    private var porcentaje: Decimal? { manual ?? actual.porcentaje }
    private var superaMaximo: Bool {
        guard let max = actual.porcentaje, let p = manual else { return false }
        return p > max
    }
    private var nueva: Decimal? {
        porcentaje.map { p in
            var r = actual.rentaActual * (1 + p / 100)
            var redondeada = Decimal()
            NSDecimalRound(&redondeada, &r, 2, .plain)
            return redondeada
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Índice", selection: $indice) {
                    ForEach(IndiceRenta.allCases) { Text($0.nombre).tag($0) }
                }
                .accessibilityIdentifier("selectorIndice")
            } footer: {
                Text(actual.motivoIndice)
            }
            .filaLista()
            Section {
                LabeledContent(indice == .pactado ? "Porcentaje pactado" : "Porcentaje a aplicar") {
                    TextField("%", value: $manual, format: .number.precision(.fractionLength(0...3)).locale(Formato.locale))
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("campoPorcentaje")
                }
                if let max = actual.porcentaje {
                    LabeledContent("Máximo", value: conSigno(max))
                }
                LabeledContent("Renta actual", value: Formato.euros(actual.rentaActual))
                LabeledContent("Renta nueva", value: nueva.map(Formato.euros) ?? "—")
                    .font(Tema.Fuente.subtitulo)
                if let fecha = actual.fechaEfecto {
                    LabeledContent("Desde", value: fecha.formatted(FormatoFecha.larga))
                }
            } footer: {
                VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                    if superaMaximo {
                        Text("No puede superar el máximo.").foregroundStyle(Tema.Color.negativo)
                    }
                    if actual.limitadoPorIrav {
                        Text("El índice elegido supera el IRAV: el máximo es el IRAV (LAU, art. 18.1).")
                            .foregroundStyle(Tema.Color.aviso)
                    }
                    if let f = actual.fuente { Text(f) }
                    Text(actual.aviso)
                }
            }
            .filaLista()
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                .filaLista()
            }
        }
        .estiloLista()
        .navigationTitle("Actualizar renta")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
            ToolbarItem(placement: .confirmationAction) {
                if aplicando { ProgressView() } else {
                    Button("Aplicar") { Task { await aplicar() } }.disabled(porcentaje == nil || superaMaximo)
                }
            }
        }
        .onAppear {
            indice = inicial.indice
            manual = inicial.porcentaje
        }
        .onChange(of: indice) { _, nuevo in
            guard nuevo != actual.indice else { return }
            Task { await recargar(nuevo) }
        }
    }

    private func recargar(_ i: IndiceRenta) async {
        do {
            propuesta = try await sesion.api.enviar(.propuestaRenta(contrato: idContrato, indice: i))
            manual = propuesta?.porcentaje
        }
        catch .noAutorizado {}
        catch { self.error = error.localizedDescription }
    }

    private func aplicar() async {
        aplicando = true
        defer { aplicando = false }
        guard let fecha = actual.fechaEfecto else { return }
        let req = ConfirmacionRenta(fechaEfecto: FechaAPI.texto(fecha), indice: indice, porcentaje: porcentaje)
        do {
            let h = try await sesion.api.enviar(.confirmarRenta(contrato: idContrato, req))
            await alAplicar(h)
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
