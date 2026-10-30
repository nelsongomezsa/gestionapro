import AppKit
import CoreGraphics

// Icono de GestionAp: fondo azul marino y un edificio en azul eléctrico con ventanas,
// junto a uno más bajo. Formas grandes y sin texto para que se reconozca a 29 pt.
func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func dibujar(lado: Int, fondoTransparente: Bool) -> CGImage {
    let s = CGFloat(lado)
    let ctx = CGContext(data: nil, width: lado, height: lado, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let u = s / 1024
    if !fondoTransparente {
        // Fondo: marino con un ligero degradado vertical (más claro arriba).
        let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [color(0x16264A), color(0x0B1220)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
    }
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, r: CGFloat, _ c: CGColor) {
        ctx.setFillColor(c)
        ctx.addPath(CGPath(roundedRect: CGRect(x: x * u, y: y * u, width: w * u, height: h * u),
                           cornerWidth: r * u, cornerHeight: r * u, transform: nil))
        ctx.fillPath()
    }
    // Coordenadas con el origen abajo a la izquierda. Suelo común en y = 250.
    // Edificio bajo (detrás, a la derecha): azul claro apagado.
    rect(560, 250, 230, 330, r: 36, color(0x8DB6FF, 0.55))
    // Edificio alto: azul eléctrico.
    rect(260, 250, 330, 540, r: 44, color(0x4C8DFF))
    // Ventanas del alto: 2 columnas x 3 filas, recortadas en marino.
    let ventana = color(0x0E1830)
    for fila in 0..<3 {
        for col in 0..<2 {
            rect(322 + CGFloat(col) * 130, 560 - CGFloat(fila) * 120, 76, 76, r: 14, ventana)
        }
    }
    // Ventanas del bajo: una columna de 2.
    for fila in 0..<2 { rect(660, 440 - CGFloat(fila) * 110, 64, 64, r: 12, color(0x0E1830, 0.8)) }
    return ctx.makeImage()!
}

func guardar(_ img: CGImage, _ ruta: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: ruta))
}

let args = CommandLine.arguments
guardar(dibujar(lado: 1024, fondoTransparente: false), args[1])
guardar(dibujar(lado: 360, fondoTransparente: false), args[2])
