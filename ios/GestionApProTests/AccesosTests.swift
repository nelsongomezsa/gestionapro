import Foundation
import Security
import Testing
@testable import GestionApPro

@MainActor
struct AccesosTests {
    private func conversacion(_ contrato: Int, sinLeer: Int, mio: Bool = false, hace segundos: TimeInterval = 0) -> Conversacion {
        let json = """
        {"idContrato":\(contrato),"con":"Inquilino \(contrato)","asunto":"Hab. 1","ultimoMensaje":"Hola",
         "fecha":"\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-segundos)))","ultimoMio":\(mio),"sinLeer":\(sinLeer)}
        """
        return try! JSONCoding.decoder().decode(Conversacion.self, from: Data(json.utf8))
    }

    @Test func buzon_sumaLosSinLeer_yNoAvisaEnLaPrimeraCarga() {
        let b = BuzonMensajes()
        b.aplicar([conversacion(1, sinLeer: 2), conversacion(2, sinLeer: 1)])
        #expect(b.sinLeer == 3)
        #expect(b.nuevo == nil)
    }

    @Test func buzon_siSube_avisaConLaConversacionMasReciente() {
        let b = BuzonMensajes()
        b.aplicar([conversacion(1, sinLeer: 1, hace: 600)])
        b.aplicar([conversacion(1, sinLeer: 1, hace: 600), conversacion(2, sinLeer: 1, hace: 5)])
        #expect(b.sinLeer == 2)
        #expect(b.nuevo?.idContrato == 2)
    }

    @Test func buzon_siBaja_noAvisa() {
        let b = BuzonMensajes()
        b.aplicar([conversacion(1, sinLeer: 2)])
        b.aplicar([conversacion(1, sinLeer: 0)])
        #expect(b.sinLeer == 0)
        #expect(b.nuevo == nil)
    }

    @Test func contexto_seEnviaComoEsperaLaAPI() throws {
        let p = PreguntaAsistente(mensaje: "¿Qué tal?", historial: [], contexto: ContextoPantalla.contrato(7).paraAPI)
        let json = try #require(String(data: JSONEncoder().encode(p), encoding: .utf8))
        #expect(json.contains(#""contexto":{"#))
        #expect(json.contains(#""tipo":"CONTRATO""#))
        let sin = try #require(String(data: JSONEncoder().encode(PreguntaAsistente(mensaje: "Hola", historial: [])), encoding: .utf8))
        #expect(!sin.contains("contexto"))
    }
}

@MainActor
struct ProductoTests {
    @Test func accionPendiente_seConsumeUnaSolaVez() {
        let a = AccionPendiente()
        a.acceso = .pago
        #expect(a.tomar() == .pago)
        #expect(a.tomar() == nil)
    }

    @Test func bienvenida_soloLaPrimeraVez_yNuncaEnLosTestsDeUI() {
        #expect(BienvenidaView.debeMostrarse(vista: false, argumentos: []))
        #expect(!BienvenidaView.debeMostrarse(vista: true, argumentos: []))
        #expect(!BienvenidaView.debeMostrarse(vista: false, argumentos: ["-reiniciarSesion"]))
    }
}

struct SeguridadAppTests {
    /// El token de sesión solo se puede leer con el móvil desbloqueado y no sale del dispositivo.
    @Test func token_soloConElMovilDesbloqueado() {
        #expect(KeychainTokenStore.accesibilidad as String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }
}
