import UIKit

/// Foto lista para subir: como mucho 2000 px de lado y en JPEG, para no mandar 12 MB por foto.
enum FotoPreparada {
    static let ladoMaximo: CGFloat = 2000

    static func jpeg(_ datos: Data) -> Data? {
        guard let imagen = UIImage(data: datos) else { return nil }
        let lado = max(imagen.size.width, imagen.size.height)
        let escala = min(1, ladoMaximo / lado)
        let tamano = CGSize(width: imagen.size.width * escala, height: imagen.size.height * escala)
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        let reducida = UIGraphicsImageRenderer(size: tamano, format: formato).image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: tamano))
        }
        return reducida.jpegData(compressionQuality: 0.75)
    }
}
