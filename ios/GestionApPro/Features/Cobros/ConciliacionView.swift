import SwiftUI
import UniformTypeIdentifiers

/// Conciliación con el banco: se elige el extracto en CSV, la API propone a qué contrato
/// corresponde cada ingreso y el propietario marca los que quiere registrar como pagos.
/// Nada se registra sin confirmación.
struct ConciliacionView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let alRegistrar: () -> Void

    @State private var eligiendo = false
    @State private var analizando = false
    @State private var analisis: AnalisisConciliacion?
    @State private var marcados: Set<Int> = []
    @State private var registrando = false
    @State private var hecho: Int?
    @State private var error: String?

    private var seleccion: [AnalisisConciliacion.Analizado] {
        analisis?.propuestas.filter { marcados.contains($0.indice) } ?? []
    }

    var body: some View {
        List {
            if let a = analisis {
                if a.propuestas.isEmpty {
                    EstadoVacio(icono: "doc.text.magnifyingglass", titulo: "Sin coincidencias",
                                mensaje: "Ningún ingreso del extracto encaja con tus contratos.")
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(a.propuestas) { p in
                            FilaPropuesta(analizado: p, marcado: marcados.contains(p.indice)) {
                                if marcados.contains(p.indice) { marcados.remove(p.indice) } else { marcados.insert(p.indice) }
                            }
                        }
                    } header: {
                        Text("Propuestas (\(a.propuestas.count))")
                    } footer: {
                        Text("Confianza alta: el importe coincide con la renta y el concepto nombra al inquilino. Revisa las de confianza media o baja antes de marcarlas.")
                    }
                    .filaLista()
                }
                if !a.sinPropuesta.isEmpty {
                    Section {
                        ForEach(Array(a.sinPropuesta.enumerated()), id: \.offset) { _, m in
                            FilaMetrica(titulo: m.concepto, valor: Formato.euros(m.importe),
                                        nota: m.fecha.formatted(FormatoFecha.corta))
                        }
                    } header: {
                        Text("Ingresos sin contrato (\(a.sinPropuesta.count))")
                    }
                    .filaLista()
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: Tema.Espacio.s) {
                        Label("Descarga el extracto de tu banco en CSV", systemImage: "1.circle")
                        Label("Elígelo aquí: la app propone qué ingreso es de qué inquilino", systemImage: "2.circle")
                        Label("Marca los que estén bien y regístralos como pagos, con su recibo", systemImage: "3.circle")
                    }
                    .font(Tema.Fuente.detalle)
                    if analizando {
                        HStack { ProgressView(); Text("Analizando el extracto…") }
                    } else {
                        Button { eligiendo = true } label: { Label("Elegir extracto (CSV)", systemImage: "doc.badge.plus") }
                            .accessibilityIdentifier("botonElegirExtracto")
                    }
                } footer: {
                    Text("Funciona con el formato genérico y los extractos habituales de Santander, BBVA, CaixaBank, Sabadell e ING.")
                }
                .filaLista()
            }
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                    .filaLista()
            }
        }
        .estiloLista()
        .navigationTitle("Conciliar con el banco")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { cerrar() } }
            if analisis != nil {
                ToolbarItem(placement: .confirmationAction) {
                    if registrando { ProgressView() } else {
                        Button(seleccion.count == 1 ? "Registrar 1 pago" : "Registrar \(seleccion.count) pagos") {
                            Task { await registrar() }
                        }
                        .disabled(seleccion.isEmpty)
                        .accessibilityIdentifier("botonRegistrarConciliacion")
                    }
                }
            }
        }
        .fileImporter(isPresented: $eligiendo, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { resultado in
            guard case let .success(url) = resultado else { return }
            Task { await analizar(url) }
        }
        .alert("Pagos registrados", isPresented: Binding(get: { hecho != nil }, set: { if !$0 { hecho = nil; cerrar() } })) {
            Button("Aceptar") {}
        } message: {
            Text(hecho == 1 ? "Se ha registrado 1 pago con su recibo." : "Se han registrado \(hecho ?? 0) pagos con sus recibos.")
        }
    }

    private func analizar(_ url: URL) async {
        let acceso = url.startAccessingSecurityScopedResource()
        defer { if acceso { url.stopAccessingSecurityScopedResource() } }
        guard let datos = try? Data(contentsOf: url), datos.count <= 2 * 1024 * 1024 else {
            error = "No se pudo leer el archivo (máximo 2 MB)"
            return
        }
        analizando = true
        defer { analizando = false }
        do {
            let a = try await sesion.api.subir(Rutas.analizarExtracto, archivo: datos, nombre: url.lastPathComponent,
                                               tipo: "text/csv", respuesta: AnalisisConciliacion.self)
            analisis = a
            marcados = Set(a.propuestas.filter { $0.propuesta.preseleccionada && !$0.propuesta.yaRegistrado }.map(\.indice))
            error = nil
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func registrar() async {
        registrando = true
        defer { registrando = false }
        let req = ConfirmarConciliacion(pagos: seleccion.map {
            .init(idContrato: $0.propuesta.idContrato, fecha: FechaAPI.texto($0.movimiento.fecha),
                  importe: $0.movimiento.importe, metodoPago: .transferencia)
        })
        do {
            let r = try await sesion.api.enviar(.confirmarConciliacion(req))
            alRegistrar()
            hecho = r.pagos.count
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct FilaPropuesta: View {
    let analizado: AnalisisConciliacion.Analizado
    let marcado: Bool
    let alternar: () -> Void

    private var tono: Tono {
        switch analizado.propuesta.confianza {
        case "ALTA": .positivo
        case "MEDIA": .aviso
        default: .neutro
        }
    }

    var body: some View {
        let m = analizado.movimiento
        let p = analizado.propuesta
        Button(action: alternar) {
            HStack(alignment: .top, spacing: Tema.Espacio.s) {
                Image(systemName: marcado ? "checkmark.circle.fill" : "circle")
                    .font(Tema.Fuente.subtitulo)
                    .foregroundStyle(marcado ? Tema.Color.primario : Tema.Color.textoSecundario)
                VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(p.inquilino).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                        Spacer(minLength: Tema.Espacio.xs)
                        Text(Formato.euros(m.importe)).font(Tema.Fuente.cifraPequena).foregroundStyle(Tema.Color.positivo)
                    }
                    Text(m.concepto).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                    Text("\(m.fecha.formatted(FormatoFecha.corta)) · Hab. \(p.numeroHabitacion) · renta \(Formato.euros(p.renta))")
                        .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                    HStack(spacing: Tema.Espacio.xxs) {
                        InsigniaEstado(texto: "Confianza \(p.confianza.lowercased())", tono: tono)
                        if p.yaRegistrado { InsigniaEstado(texto: "Ya registrado", tono: .neutro) }
                    }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(marcado ? [.isSelected] : [])
        .accessibilityHint(marcado ? "Toca para no registrarlo" : "Toca para registrarlo")
        .accessibilityIdentifier("filaPropuesta")
    }
}
