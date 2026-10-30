import Foundation

/// Enlaces para contactar con un inquilino (en escritorio se enviaba un email con JavaMail).
enum Contacto {
    static func soloDigitos(_ telefono: String) -> String {
        telefono.filter { $0.isNumber || $0 == "+" }
    }

    static func llamada(_ telefono: String) -> URL? {
        URL(string: "tel:" + soloDigitos(telefono))
    }

    static func email(_ direccion: String, asunto: String? = nil) -> URL? {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = direccion
        if let asunto { c.queryItems = [URLQueryItem(name: "subject", value: asunto)] }
        return c.url
    }

    /// wa.me exige el número internacional sin "+": a los de 9 cifras se les antepone 34 (España).
    static func whatsApp(_ telefono: String, mensaje: String? = nil) -> URL? {
        var numero = soloDigitos(telefono).replacingOccurrences(of: "+", with: "")
        if numero.count == 9 { numero = "34" + numero }
        var c = URLComponents(string: "https://wa.me/\(numero)")
        if let mensaje { c?.queryItems = [URLQueryItem(name: "text", value: mensaje)] }
        return c?.url
    }

    /// Tarjeta de contacto (vCard 3.0) para compartir.
    static func vCard(nombre: String, apellidos: String, telefono: String?, email: String?) -> String {
        var lineas = ["BEGIN:VCARD", "VERSION:3.0", "N:\(apellidos);\(nombre);;;", "FN:\(nombre) \(apellidos)"]
        if let telefono, !telefono.isEmpty { lineas.append("TEL;TYPE=CELL:\(soloDigitos(telefono))") }
        if let email, !email.isEmpty { lineas.append("EMAIL:\(email)") }
        lineas.append("END:VCARD")
        return lineas.joined(separator: "\r\n")
    }
}
