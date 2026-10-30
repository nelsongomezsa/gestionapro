import CoreImage.CIFilterBuiltins
import UIKit

enum CodigoQR {
    /// Imagen nítida del QR (sin suavizado al ampliar). Nivel de corrección M, el que pide
    /// el estándar EPC para los QR de pago SEPA.
    static func imagen(de texto: String, lado: CGFloat = 600) -> UIImage? {
        let filtro = CIFilter.qrCodeGenerator()
        filtro.message = Data(texto.utf8)
        filtro.correctionLevel = "M"
        guard let salida = filtro.outputImage else { return nil }
        let escala = lado / salida.extent.width
        let ampliada = salida.transformed(by: CGAffineTransform(scaleX: escala, y: escala))
        guard let cg = CIContext().createCGImage(ampliada, from: ampliada.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
