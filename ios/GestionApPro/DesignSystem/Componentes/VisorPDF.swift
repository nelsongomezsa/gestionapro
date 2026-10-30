import PDFKit
import SwiftUI

/// Documento PDF para mostrar en VisorPDF.
struct DocumentoPDF: Identifiable {
    let id = UUID()
    let titulo: String
    let datos: Data

    /// Copia temporal con nombre legible, para compartir o guardar en Archivos.
    var archivo: URL {
        let nombre = titulo.replacingOccurrences(of: "/", with: "-") + ".pdf"
        let url = FileManager.default.temporaryDirectory.appending(path: nombre)
        try? datos.write(to: url, options: .atomic)
        return url
    }
}

/// Visor de PDF con compartir e imprimir (sustituye a "guardar en el Escritorio").
struct VisorPDF: View {
    let documento: DocumentoPDF
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            VistaPDFKit(datos: documento.datos)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(documento.titulo)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { cerrar() }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Imprimir", systemImage: "printer") { imprimir() }
                        ShareLink(item: documento.archivo) {
                            Label("Compartir", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }

    private func imprimir() {
        let info = UIPrintInfo.printInfo()
        info.jobName = documento.titulo
        info.outputType = .general
        let controlador = UIPrintInteractionController.shared
        controlador.printInfo = info
        controlador.printingItem = documento.datos
        controlador.present(animated: true)
    }
}

private struct VistaPDFKit: UIViewRepresentable {
    let datos: Data

    func makeUIView(context: Context) -> PDFView {
        let vista = PDFView()
        vista.autoScales = true
        vista.displayMode = .singlePageContinuous
        vista.backgroundColor = .systemGroupedBackground
        vista.document = PDFDocument(data: datos)
        return vista
    }

    func updateUIView(_ vista: PDFView, context: Context) {}
}

extension View {
    func visorPDF(_ documento: Binding<DocumentoPDF?>) -> some View {
        sheet(item: documento) { VisorPDF(documento: $0) }
    }
}
