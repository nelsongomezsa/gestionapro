import SwiftUI

/// Resumen fiscal anual de un piso (orientativo): ingresos, gastos deducibles con su límite,
/// amortizaciones y rendimiento neto, con PDF y CSV para el asesor.
struct ResumenFiscalView: View {
    @Environment(SesionStore.self) private var sesion
    let piso: PisoBreve

    @State private var anio = Calendar.current.component(.year, from: .now) - 1
    @State private var catastral: Decimal?
    @State private var construccion: Decimal?
    @State private var estado: EstadoCarga<ResumenFiscal> = .cargando
    @State private var documento: DocumentoPDF?
    @State private var compartir: Compartible?
    @State private var error: String?

    /// Los valores catastrales se recuerdan en este iPhone (no cambian de un año a otro).
    private var claveCatastro: String { "catastro-\(piso.id)" }

    var body: some View {
        List {
            Section {
                HStack {
                    Button { anio -= 1 } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Año anterior")
                    Spacer()
                    Text("Ejercicio \(String(anio))").font(Tema.Fuente.tituloSeccion).monospacedDigit()
                    Spacer()
                    Button { anio += 1 } label: { Image(systemName: "chevron.right") }
                        .disabled(anio >= Calendar.current.component(.year, from: .now))
                        .accessibilityLabel("Año siguiente")
                }
                .buttonStyle(.borderless)
            }
            .filaLista()

            Section {
                LabeledContent("Valor catastral") {
                    TextField("€", value: $catastral, format: .number.precision(.fractionLength(0...2)).locale(Formato.locale))
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
                LabeledContent("De la construcción") {
                    TextField("€", value: $construccion, format: .number.precision(.fractionLength(0...2)).locale(Formato.locale))
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Recibo del IBI")
            } footer: {
                Text("Para la amortización del inmueble (3 % de la construcción, sin el suelo).")
            }
            .filaLista()

            switch estado {
            case .cargando:
                Section { ProgressView().frame(maxWidth: .infinity) }.filaLista()
            case let .error(mensaje):
                Section { Label(mensaje, systemImage: "exclamationmark.triangle").foregroundStyle(Tema.Color.negativo) }.filaLista()
            case let .cargado(r):
                Section {
                    FilaMetrica(titulo: "Ingresos", valor: Formato.euros(r.ingresos),
                                nota: r.numeroPagos == 1 ? "1 pago" : "\(r.numeroPagos) pagos", tono: .positivo)
                    ForEach(r.gastosConLimite, id: \.self) { l in
                        FilaMetrica(titulo: l.concepto, valor: "− " + Formato.euros(l.importe))
                    }
                    if r.excesoParaAniosSiguientes > 0 {
                        FilaMetrica(titulo: "Exceso para los 4 años siguientes", valor: Formato.euros(r.excesoParaAniosSiguientes),
                                    nota: "Intereses, reparación y conservación no pueden superar los ingresos", tono: .aviso)
                    }
                    ForEach(r.otrosGastos, id: \.self) { l in
                        FilaMetrica(titulo: l.concepto, valor: "− " + Formato.euros(l.importe))
                    }
                    FilaMetrica(titulo: "Amortización del inmueble",
                                valor: r.amortizacionInmueble.map { "− " + Formato.euros($0) } ?? "—", nota: r.baseAmortizacion)
                    FilaMetrica(titulo: "Amortización del mobiliario", valor: "− " + Formato.euros(r.amortizacionMobiliario),
                                nota: "10 % anual")
                    FilaMetrica(titulo: "Rendimiento neto", valor: Formato.euros(r.rendimientoNeto),
                                tono: Tono.signo(r.rendimientoNeto))
                } header: {
                    Text("Orientativo")
                } footer: {
                    VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                        ForEach(r.notas, id: \.self) { Text($0) }
                    }
                }
                .filaLista()

                Section {
                    Button { Task { await exportar("pdf") } } label: { Label("PDF para el asesor", systemImage: "doc.richtext") }
                    Button { Task { await exportar("csv") } } label: { Label("Hoja de cálculo (CSV)", systemImage: "tablecells") }
                }
                .filaLista()
            }
        }
        .estiloLista()
        .navigationTitle("Resumen fiscal")
        .navigationBarTitleDisplayMode(.inline)
        .visorPDF($documento)
        .hojaCompartir($compartir)
        .alertaError($error)
        .onAppear(perform: leerCatastro)
        .task(id: "\(anio)-\(catastral.map { "\($0)" } ?? "")-\(construccion.map { "\($0)" } ?? "")") {
            guardarCatastro()
            await cargar()
        }
    }

    private func cargar() async {
        do {
            estado = .cargado(try await sesion.api.enviar(.resumenFiscal(piso: piso.id, anio: anio, catastral: catastral,
                                                                          construccion: construccion)))
        } catch .noAutorizado {
        } catch {
            estado = .error(error.localizedDescription)
        }
    }

    private func exportar(_ formato: String) async {
        do {
            let datos = try await sesion.api.descargar(Rutas.resumenFiscal(piso: piso.id, formato: formato),
                                                       consulta: consultaResumenFiscal(anio: anio, catastral: catastral,
                                                                                       construccion: construccion),
                                                       tipo: formato == "pdf" ? "application/pdf" : "text/csv")
            let titulo = "Resumen fiscal \(anio) · \(piso.direccion)"
            if formato == "pdf" {
                documento = DocumentoPDF(titulo: titulo, datos: datos)
            } else {
                let url = FileManager.default.temporaryDirectory.appending(path: titulo.replacingOccurrences(of: "/", with: "-") + ".csv")
                try? datos.write(to: url, options: .atomic)
                compartir = Compartible(elementos: [url], asunto: titulo)
            }
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func leerCatastro() {
        guard let guardado = UserDefaults.standard.array(forKey: claveCatastro) as? [String], guardado.count == 2 else { return }
        catastral = Decimal(string: guardado[0])
        construccion = Decimal(string: guardado[1])
    }

    private func guardarCatastro() {
        guard let catastral, let construccion else { return }
        UserDefaults.standard.set(["\(catastral)", "\(construccion)"], forKey: claveCatastro)
    }
}
