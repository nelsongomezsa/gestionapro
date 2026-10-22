import Foundation

/// Configuración que llega del Info.plist (clave APIBaseURL, rellenada desde el .xcconfig de cada configuración).
enum AppConfig {
    static let apiBaseURL: URL = {
        guard let texto = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              let url = URL(string: texto) else {
            preconditionFailure("Falta APIBaseURL en el Info.plist (ver Config/*.xcconfig)")
        }
        #if !DEBUG
        // Release no tiene excepción ATS; además no se admite una URL que no sea HTTPS.
        precondition(url.scheme == "https", "En Release la API debe servirse por HTTPS")
        #endif
        return url
    }()
}
