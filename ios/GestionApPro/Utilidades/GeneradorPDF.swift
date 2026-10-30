import UIKit

/// PDF de una tabla, generado en el móvil (equivale a PdfExporter del escritorio, que lo
/// guardaba en el Escritorio; aquí se muestra en VisorPDF para compartir o imprimir).
enum GeneradorPDF {

    struct Columna {
        let titulo: String
        /// Proporción del ancho disponible.
        let peso: CGFloat
        var alineacion: NSTextAlignment = .left
    }

    private static let pagina = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 en puntos
    private static let margen: CGFloat = 40
    private static let morado = UIColor(hex: 0x6C63FF)

    static func tabla(titulo: String, subtitulo: String? = nil, columnas: [Columna], filas: [[String]]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pagina, format: formato(titulo: titulo))
        let ancho = pagina.width - 2 * margen
        let totalPesos = columnas.reduce(0) { $0 + $1.peso }
        let anchos = columnas.map { ancho * $0.peso / totalPesos }

        return renderer.pdfData { contexto in
            var y: CGFloat = 0
            var numeroPagina = 0

            func nuevaPagina() {
                contexto.beginPage()
                numeroPagina += 1
                y = margen
                if numeroPagina == 1 {
                    y = dibujar(titulo, en: CGPoint(x: margen, y: y), ancho: ancho,
                                fuente: .systemFont(ofSize: 20, weight: .bold), color: morado) + 4
                    if let subtitulo {
                        y = dibujar(subtitulo, en: CGPoint(x: margen, y: y), ancho: ancho,
                                    fuente: .systemFont(ofSize: 10), color: .darkGray) + 4
                    }
                    let generado = "Generado el " + Date.now.formatted(.dateTime.day().month(.wide).year().locale(Formato.locale))
                    y = dibujar(generado, en: CGPoint(x: margen, y: y), ancho: ancho,
                                fuente: .systemFont(ofSize: 9), color: .gray) + 14
                }
                y = fila(columnas.map(\.titulo), y: y, anchos: anchos, columnas: columnas,
                         fuente: .systemFont(ofSize: 9, weight: .semibold), fondo: morado.withAlphaComponent(0.12))
                let pie = "GestionAp PRO · Pág. \(numeroPagina)"
                _ = dibujar(pie, en: CGPoint(x: margen, y: pagina.height - margen + 10), ancho: ancho,
                            fuente: .systemFont(ofSize: 8), color: .gray, alineacion: .right)
            }

            nuevaPagina()
            for (indice, valores) in filas.enumerated() {
                let alto = altoFila(valores, anchos: anchos, fuente: .systemFont(ofSize: 9))
                if y + alto > pagina.height - margen { nuevaPagina() }
                y = fila(valores, y: y, anchos: anchos, columnas: columnas, fuente: .systemFont(ofSize: 9),
                         fondo: indice.isMultiple(of: 2) ? nil : UIColor(white: 0.96, alpha: 1))
            }
            if filas.isEmpty {
                _ = dibujar("Sin datos.", en: CGPoint(x: margen, y: y + 8), ancho: ancho,
                            fuente: .systemFont(ofSize: 10), color: .gray)
            }
        }
    }

    /// Informe por secciones de pares "concepto → valor" (p. ej. el resultado de la calculadora).
    static func secciones(titulo: String, subtitulo: String? = nil, _ secciones: [(String, [(String, String)])]) -> Data {
        let r = UIGraphicsPDFRenderer(bounds: pagina, format: formato(titulo: titulo))
        let ancho = pagina.width - 2 * margen
        let columnas = [Columna(titulo: "", peso: 3), Columna(titulo: "", peso: 2, alineacion: .right)]
        let anchos = [ancho * 0.6, ancho * 0.4]
        return r.pdfData { contexto in
            contexto.beginPage()
            var y = dibujar(titulo, en: CGPoint(x: margen, y: margen), ancho: ancho,
                            fuente: .systemFont(ofSize: 20, weight: .bold), color: morado) + 4
            if let subtitulo {
                y = dibujar(subtitulo, en: CGPoint(x: margen, y: y), ancho: ancho, fuente: .systemFont(ofSize: 10), color: .darkGray) + 4
            }
            let generado = "Generado el " + Date.now.formatted(.dateTime.day().month(.wide).year().locale(Formato.locale))
            y = dibujar(generado, en: CGPoint(x: margen, y: y), ancho: ancho, fuente: .systemFont(ofSize: 9), color: .gray) + 14
            for (nombre, filas) in secciones {
                if y + 40 > pagina.height - margen { contexto.beginPage(); y = margen }
                y = dibujar(nombre.uppercased(), en: CGPoint(x: margen, y: y), ancho: ancho,
                            fuente: .systemFont(ofSize: 11, weight: .semibold), color: morado) + 4
                for (i, par) in filas.enumerated() {
                    if y + 20 > pagina.height - margen { contexto.beginPage(); y = margen }
                    y = fila([par.0, par.1], y: y, anchos: anchos, columnas: columnas, fuente: .systemFont(ofSize: 10),
                             fondo: i.isMultiple(of: 2) ? nil : UIColor(white: 0.96, alpha: 1))
                }
                y += 12
            }
        }
    }

    private static func formato(titulo: String) -> UIGraphicsPDFRendererFormat {
        let f = UIGraphicsPDFRendererFormat()
        f.documentInfo = [kCGPDFContextTitle as String: titulo, kCGPDFContextCreator as String: "GestionAp PRO"]
        return f
    }

    private static func atributos(_ fuente: UIFont, _ color: UIColor, _ alineacion: NSTextAlignment) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.alignment = alineacion
        p.lineBreakMode = .byWordWrapping
        return [.font: fuente, .foregroundColor: color, .paragraphStyle: p]
    }

    /// Dibuja texto y devuelve la y de su borde inferior.
    private static func dibujar(_ texto: String, en origen: CGPoint, ancho: CGFloat, fuente: UIFont,
                                color: UIColor, alineacion: NSTextAlignment = .left) -> CGFloat {
        let attrs = atributos(fuente, color, alineacion)
        let alto = (texto as NSString).boundingRect(with: CGSize(width: ancho, height: .greatestFiniteMagnitude),
                                                    options: .usesLineFragmentOrigin, attributes: attrs, context: nil).height
        (texto as NSString).draw(in: CGRect(x: origen.x, y: origen.y, width: ancho, height: ceil(alto)), withAttributes: attrs)
        return origen.y + ceil(alto)
    }

    private static func altoFila(_ valores: [String], anchos: [CGFloat], fuente: UIFont) -> CGFloat {
        zip(valores, anchos).map { valor, ancho in
            (valor as NSString).boundingRect(with: CGSize(width: ancho - 8, height: .greatestFiniteMagnitude),
                                             options: .usesLineFragmentOrigin, attributes: [.font: fuente], context: nil).height
        }.max().map { ceil($0) + 8 } ?? 18
    }

    private static func fila(_ valores: [String], y: CGFloat, anchos: [CGFloat], columnas: [Columna],
                             fuente: UIFont, fondo: UIColor?) -> CGFloat {
        let alto = altoFila(valores, anchos: anchos, fuente: fuente)
        if let fondo {
            fondo.setFill()
            UIRectFill(CGRect(x: margen, y: y, width: anchos.reduce(0, +), height: alto))
        }
        var x = margen
        for (i, valor) in valores.enumerated() where i < anchos.count {
            _ = dibujar(valor, en: CGPoint(x: x + 4, y: y + 4), ancho: anchos[i] - 8, fuente: fuente,
                        color: .black, alineacion: columnas[i].alineacion)
            x += anchos[i]
        }
        return y + alto
    }
}
