import XCTest

/// Recorre la app y guarda capturas en la carpeta indicada (docs/capturas/<fase>/<modo>/).
///
/// No es un test de lógica: necesita la API en marcha y credenciales, que se pasan por
/// variables de entorno con el prefijo TEST_RUNNER_ (xcodebuild se lo quita):
///   TEST_RUNNER_CAPTURAS_DIR, TEST_RUNNER_CAPTURAS_EMAIL, TEST_RUNNER_CAPTURAS_PASSWORD
/// Sin ellas, se salta. Ver docs/capturas/README.md.
final class CapturasUITests: XCTestCase {

    @MainActor
    func test4A() throws {
        let r = try Recorrido.iniciar()

        r.esperar(r.app.staticTexts["Cash flow mensual de la cartera"])
        r.capturar("02-inicio")

        r.pestana("Pisos")
        r.esperar(r.app.buttons["tarjetaPiso"].firstMatch)
        // La lista se dibuja al desplazarse (LazyVStack): se comprueba el contador visible.
        r.esperar(r.app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "8 pisos")).firstMatch)
        r.capturar("03-pisos")

        r.app.buttons["tarjetaPiso"].firstMatch.tap()
        r.esperar(r.app.staticTexts["Rentabilidad bruta"])
        r.capturar("04-detalle-piso")
        r.app.swipeUp()
        r.capturar("05-detalle-piso-abajo")

        r.pestana("Más")
        r.esperar(r.app.buttons["Calculadora de rentabilidad"])
        r.capturar("06-mas")

        r.app.buttons["Calculadora de rentabilidad"].tap()
        r.esperar(r.app.staticTexts["Rent. bruta"])
        r.pausa(2) // resumen en vivo
        r.capturar("07-calculadora")

        r.desplazarHasta(r.app.buttons["Ver desglose completo"]).tap()
        r.esperar(r.app.staticTexts["¿A dónde va el alquiler?"])
        r.capturar("08-calculadora-desglose")

        r.atras()
        r.atras()
        r.app.buttons["enlacePerfil"].firstMatch.tap()
        r.esperar(r.app.staticTexts["Cuenta"])
        r.capturar("09-perfil")
    }
}

extension CapturasUITests {

    @MainActor
    func test4B() throws {
        let r = try Recorrido.iniciar()
        r.esperar(r.app.staticTexts["Cash flow mensual de la cartera"])

        // Habitaciones de un piso
        r.pestana("Pisos")
        r.esperar(r.app.buttons["tarjetaPiso"].firstMatch)
        r.app.buttons["tarjetaPiso"].firstMatch.tap()
        r.desplazarHasta(r.app.buttons["enlaceHabitaciones"]).tap()
        r.esperar(r.app.staticTexts["Desliza para editar, borrar o cambiar el estado."])
        r.capturar("01-habitaciones")

        r.app.cells.element(boundBy: 1).swipeLeft()
        r.pausa(1)
        r.capturar("02-habitaciones-deslizar")
        r.app.cells.element(boundBy: 1).swipeRight()

        r.app.buttons["Añadir"].tap()
        r.esperar(r.app.navigationBars["Nueva habitación"])
        r.capturar("03-habitacion-nueva")
        r.app.buttons["Cancelar"].tap()

        r.atras()
        r.desplazarHasta(r.app.buttons["enlaceMapa"]).tap()
        r.esperar(r.app.buttons["Abrir en Mapas"], timeout: 20)
        r.pausa(3) // teselas del mapa
        r.capturar("04-mapa-piso")

        // Inquilinos
        r.pestana("Más")
        r.app.buttons["Inquilinos"].tap()
        r.esperar(r.app.buttons["filaInquilino"].firstMatch)
        r.capturar("05-inquilinos")

        r.app.buttons["filaInquilino"].firstMatch.tap()
        r.esperar(r.app.staticTexts["Contrato activo"])
        r.capturar("06-ficha-inquilino")

        r.app.buttons["QR de pago del mes"].tap()
        r.esperar(r.app.navigationBars["QR de pago"])
        r.capturar("07-qr-pago")
        r.app.buttons["Cerrar"].tap()

        if r.app.buttons["Invitar a la app"].exists {
            r.app.buttons["Invitar a la app"].tap()
            r.esperar(r.app.staticTexts["Código de invitación"])
            r.capturar("08-invitacion")
            r.app.buttons["Cerrar"].tap()
        }

        // Datos de cobro (IBAN del QR)
        r.pestana("Más") // pulsar la pestaña ya activa vuelve a su raíz
        r.app.buttons["enlacePerfil"].firstMatch.tap()
        r.app.buttons["botonDatosCobro"].tap()
        r.esperar(r.app.navigationBars["Datos de cobro"])
        r.capturar("09-datos-cobro")
    }
}

/// Sesión de la app abierta y lista para capturar.
@MainActor
struct Recorrido {
    let app: XCUIApplication
    let carpeta: URL

    static func iniciar() throws -> Recorrido {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["CAPTURAS_DIR"], let email = env["CAPTURAS_EMAIL"], let password = env["CAPTURAS_PASSWORD"] else {
            throw XCTSkip("Faltan CAPTURAS_DIR, CAPTURAS_EMAIL o CAPTURAS_PASSWORD")
        }
        let carpeta = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)

        let app = XCUIApplication()
        app.launchArguments = ["-reiniciarSesion"]
        app.launch()

        let r = Recorrido(app: app, carpeta: carpeta)
        let campoEmail = app.textFields["Email"]
        r.esperar(campoEmail)
        r.capturar("01-login")
        campoEmail.tap()
        campoEmail.typeText(email)
        let campoPassword = app.secureTextFields["Contraseña"]
        campoPassword.tap()
        campoPassword.typeText(password)
        app.buttons["Iniciar sesión"].tap()
        return r
    }

    func esperar(_ elemento: XCUIElement, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(elemento.waitForExistence(timeout: timeout), "No apareció: \(elemento)", file: file, line: line)
    }

    /// Desliza hacia arriba hasta que el elemento se pueda tocar (máx. 8 veces).
    @discardableResult
    func desplazarHasta(_ elemento: XCUIElement) -> XCUIElement {
        var intentos = 0
        while !(elemento.exists && elemento.isHittable) && intentos < 8 {
            app.swipeUp()
            intentos += 1
        }
        // Si se ha deslizado, esperar a que pare la inercia: un toque sobre una lista en
        // movimiento solo la frena y no activa el elemento.
        if intentos > 0 { pausa(1.2) }
        return elemento
    }

    func pestana(_ nombre: String) {
        app.tabBars.buttons[nombre].tap()
    }

    func atras() {
        app.navigationBars.buttons.firstMatch.tap()
    }

    func pausa(_ segundos: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "pausa")], timeout: segundos)
    }

    func capturar(_ nombre: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        do {
            try png.write(to: carpeta.appending(path: "\(nombre).png"))
        } catch {
            XCTFail("No se pudo guardar \(nombre): \(error)")
        }
    }
}
