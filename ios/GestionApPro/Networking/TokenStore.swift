import Foundation
import Security

/// Dónde se guarda el JWT. En la app, el Keychain; en tests y previews, memoria.
protocol TokenStore: Sendable {
    func leer() -> String?
    func guardar(_ token: String) throws
    func borrar()
}

/// JWT en el Keychain (nunca en UserDefaults). Solo accesible en este dispositivo,
/// tras el primer desbloqueo, y no se incluye en copias de seguridad.
struct KeychainTokenStore: TokenStore {
    /// Solo con el móvil desbloqueado y sin salir del dispositivo (ni copias ni migración a otro iPhone).
    /// La app no lee el token en segundo plano: no hace falta "tras el primer desbloqueo".
    static var accesibilidad: CFString { kSecAttrAccessibleWhenUnlockedThisDeviceOnly }

    var servicio = "com.gestionap.GestionApPro"
    var cuenta = "jwt"

    private var consulta: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: servicio,
         kSecAttrAccount as String: cuenta]
    }

    func leer() -> String? {
        var q = consulta
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data else { return nil }
        return String(data: datos, encoding: .utf8)
    }

    func guardar(_ token: String) throws {
        borrar()
        var q = consulta
        q[kSecValueData as String] = Data(token.utf8)
        q[kSecAttrAccessible as String] = Self.accesibilidad
        let estado = SecItemAdd(q as CFDictionary, nil)
        guard estado == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(estado))
        }
    }

    func borrar() {
        SecItemDelete(consulta as CFDictionary)
    }
}

/// Para tests y previews.
final class TokenStoreEnMemoria: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func leer() -> String? { lock.withLock { token } }
    func guardar(_ token: String) { lock.withLock { self.token = token } }
    func borrar() { lock.withLock { token = nil } }
}
