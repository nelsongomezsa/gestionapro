import SwiftUI

/// Estado de las firmas de un contrato; vive en la pantalla (como la fianza).
@MainActor @Observable
final class ModeloFirmas {
    var estado: EstadoFirmas?
    /// La carga falló: se muestra con un botón para reintentar (en vez de quedarse cargando).
    var fallo: String?
    var firmando: ParteFirma?
    var error: String?

    func cargar(contrato id: Int, con api: APIClient) async {
        fallo = nil
        do { estado = try await api.enviar(.firmas(contrato: id)) }
        catch .noAutorizado {}
        catch { fallo = error.localizedDescription }
    }

    func firmada(_ parte: ParteFirma) -> EstadoFirmas.Firma? {
        estado?.firmas.first { $0.parte == parte && $0.vigente }
    }
}

/// Sección "Firma": quién ha firmado, botones para firmar y el PDF firmado.
struct SeccionFirma: View {
    @Environment(SesionStore.self) private var sesion
    let modelo: ModeloFirmas
    let idContrato: Int
    /// El propietario puede recoger las dos firmas en su iPhone si firman en persona.
    let partes: [ParteFirma]
    let abrirPDF: () -> Void

    var body: some View {
        Section {
            if let e = modelo.estado {
                ForEach(ParteFirma.allCases) { p in
                    if let f = modelo.firmada(p) {
                        FilaMetrica(titulo: p.nombre, valor: "Firmado", nota: "\(f.nombre) · \(f.fecha)", tono: .positivo,
                                    icono: "checkmark.seal")
                    } else if partes.contains(p) {
                        Button { modelo.firmando = p } label: {
                            Label("Firmar como \(p.nombre.lowercased())", systemImage: "signature")
                        }
                        .accessibilityIdentifier("botonFirmar\(p.nombre)")
                    } else {
                        FilaMetrica(titulo: p.nombre, valor: "Pendiente", icono: "clock")
                    }
                }
                if !e.firmas.isEmpty {
                    Button(action: abrirPDF) { Label("Contrato firmado (PDF)", systemImage: "doc.richtext") }
                }
            } else if let fallo = modelo.fallo {
                Label(fallo, systemImage: "exclamationmark.triangle").foregroundStyle(Tema.Color.negativo)
                Button("Reintentar") { Task { await modelo.cargar(contrato: idContrato, con: sesion.api) } }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        } header: {
            HStack {
                Text("Firma")
                Spacer()
                if let e = modelo.estado {
                    InsigniaEstado(texto: e.completo ? "Firmado" : (e.cambiadoTrasFirmar ? "Cambió tras firmar" : "Sin completar"),
                                   tono: e.completo ? .positivo : (e.cambiadoTrasFirmar ? .aviso : .neutro))
                }
            }
        } footer: {
            Text(modelo.estado?.cambiadoTrasFirmar == true
                 ? "El contrato ha cambiado (por ejemplo, la renta) después de firmarlo: hay que volver a firmar."
                 : "Firma electrónica simple en pantalla. Se guardan la fecha, la IP y una huella del contrato.")
        }
        .filaLista()
    }
}

extension View {
    func firmas(_ modelo: ModeloFirmas, contrato id: Int?, api: APIClient, alFirmar: @escaping () -> Void = {}) -> some View {
        @Bindable var modelo = modelo
        return self
            .task(id: id) { if let id { await modelo.cargar(contrato: id, con: api) } }
            .sheet(item: $modelo.firmando) { parte in
                if let id {
                    NavigationStack {
                        PanelFirma(parte: parte) { png in
                            do {
                                modelo.estado = try await api.subir(Rutas.firmar(contrato: id, parte: parte), archivo: png,
                                                                    nombre: "firma.png", tipo: "image/png",
                                                                    respuesta: EstadoFirmas.self)
                                alFirmar()
                                return nil
                            } catch {
                                // Sin sesión, la app ya vuelve al login: no hay nada que mostrar aquí.
                                if case .noAutorizado = error as? APIError { return nil }
                                return error.localizedDescription
                            }
                        }
                    }
                }
            }
            .alertaError($modelo.error)
    }
}

/// Panel para dibujar la firma con el dedo. Se envía como PNG con fondo blanco.
struct PanelFirma: View {
    @Environment(\.dismiss) private var cerrar
    let parte: ParteFirma
    /// Devuelve un mensaje de error o nil si se guardó.
    let guardar: (Data) async -> String?

    @State private var trazos: [[CGPoint]] = []
    @State private var actual: [CGPoint] = []
    @State private var guardando = false
    @State private var error: String?

    private var vacia: Bool { trazos.reduce(0) { $0 + $1.count } < 10 }

    var body: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.m) {
            Text("Firma con el dedo dentro del recuadro.")
                .font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
            Lienzo(trazos: trazos + [actual])
                .frame(height: 220)
                .background(Color.white, in: .rect(cornerRadius: Tema.Radio.grande))
                .overlay(RoundedRectangle(cornerRadius: Tema.Radio.grande).strokeBorder(Tema.Color.borde))
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { actual.append($0.location) }
                    .onEnded { _ in
                        trazos.append(actual)
                        actual = []
                    })
                .accessibilityLabel("Recuadro para firmar")
                .accessibilityHint("Dibuja tu firma con el dedo")
                .accessibilityIdentifier("lienzoFirma")
            HStack {
                Button("Borrar") { trazos = [] }.disabled(trazos.isEmpty)
                Spacer()
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo)
            }
            Spacer()
        }
        .padding(Tema.Espacio.m)
        .background(Tema.Color.fondo)
        .navigationTitle("Firma del \(parte.nombre.lowercased())")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
            ToolbarItem(placement: .confirmationAction) {
                if guardando { ProgressView() } else {
                    Button("Firmar") { Task { await firmar() } }.disabled(vacia)
                }
            }
        }
        .interactiveDismissDisabled(!trazos.isEmpty)
    }

    private func firmar() async {
        let renderer = ImageRenderer(content: Lienzo(trazos: trazos).frame(width: 600, height: 220).background(Color.white))
        renderer.scale = 2
        guard let png = renderer.uiImage?.pngData() else {
            error = "No se pudo preparar la firma"
            return
        }
        guardando = true
        defer { guardando = false }
        if let fallo = await guardar(png) { error = fallo } else { cerrar() }
    }
}

/// Dibuja los trazos en negro (la firma va sobre fondo blanco también en modo oscuro).
struct Lienzo: View {
    let trazos: [[CGPoint]]

    var body: some View {
        Canvas { contexto, _ in
            for trazo in trazos where trazo.count > 1 {
                var camino = Path()
                camino.addLines(trazo)
                contexto.stroke(camino, with: .color(.black), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
