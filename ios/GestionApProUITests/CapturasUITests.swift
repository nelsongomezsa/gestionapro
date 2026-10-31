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

        r.esperar(r.elemento(contiene: "Cash flow previsto de la cartera"))
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
        r.esperar(r.elemento(contiene: "Cash flow previsto de la cartera"))

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

    static func iniciar(capturarLogin: Bool = true) throws -> Recorrido {
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
        if capturarLogin { r.capturar("01-login") }
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

    func elemento(contiene texto: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", texto)).firstMatch
    }

    func texto(empiezaPor prefijo: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] %@", prefijo)).firstMatch
    }

    /// Cierra la hoja de Compartir de iOS (botón Cerrar o deslizando hacia abajo).
    func cerrarHojaCompartir() {
        let cerrar = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cerrar", "Close"])).firstMatch
        if cerrar.waitForExistence(timeout: 2) { cerrar.tap() } else { app.swipeDown(velocity: .fast) }
        pausa(1)
    }

    /// Cierra la app y entra con otra cuenta.
    func relanzar(email: String, password: String) -> Recorrido {
        app.terminate()
        app.launchArguments = ["-reiniciarSesion"]
        app.launch()
        let campoEmail = app.textFields["Email"]
        esperar(campoEmail)
        campoEmail.tap()
        campoEmail.typeText(email)
        let campoPassword = app.secureTextFields["Contraseña"]
        campoPassword.tap()
        campoPassword.typeText(password)
        app.buttons["Iniciar sesión"].tap()
        return self
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

extension CapturasUITests {

    @MainActor
    func test4C() throws {
        let r = try Recorrido.iniciar()
        r.esperar(r.elemento(contiene: "Cash flow previsto de la cartera"))

        // Cobros
        r.pestana("Cobros")
        r.esperar(r.texto(empiezaPor: "Pendientes de cobro"))
        r.pausa(1)
        r.capturar("01-cobros")
        r.app.swipeUp()
        r.pausa(1)
        r.capturar("02-cobros-pagos")
        r.app.swipeDown()

        r.app.buttons["Registrar"].firstMatch.tap()
        r.esperar(r.app.navigationBars["Registrar pago"])
        r.pausa(1)
        r.capturar("03-registrar-pago")
        r.app.buttons["Cancelar"].tap()

        r.app.buttons["Mes anterior"].tap()
        r.pausa(2)
        r.capturar("04-cobros-mes-anterior")

        // Contratos
        r.pestana("Más")
        r.app.buttons["Contratos"].tap()
        r.esperar(r.app.buttons["filaContrato"].firstMatch)
        r.capturar("05-contratos")

        r.app.buttons["Por vencer"].tap()
        r.pausa(2)
        r.capturar("06-contratos-por-vencer")
        r.app.buttons["filaContrato"].firstMatch.swipeLeft()
        r.pausa(1)
        r.capturar("07-contrato-finalizar-deslizando")
        r.app.buttons["filaContrato"].firstMatch.swipeRight()

        r.app.buttons["filaContrato"].firstMatch.tap()
        r.esperar(r.app.buttons["Contrato de arrendamiento (PDF)"])
        r.capturar("08-contrato-detalle")

        r.app.buttons["Contrato de arrendamiento (PDF)"].tap()
        r.esperar(r.app.buttons["Imprimir"], timeout: 20)
        r.pausa(2)
        r.capturar("09-contrato-pdf")
        r.app.buttons["Cerrar"].tap()

        r.app.buttons["Enviar recordatorio de pago"].tap()
        r.pausa(3)
        r.capturar("10-recordatorio-compartir")
        r.cerrarHojaCompartir()

        r.atras()
        r.app.buttons["Nuevo contrato"].tap()
        r.esperar(r.app.navigationBars["Nuevo contrato"])
        r.pausa(1)
        r.capturar("11-nuevo-contrato")
        r.app.buttons["Cancelar"].tap()

        // Inquilino: su alquiler (solo si se pasan sus credenciales)
        let env = ProcessInfo.processInfo.environment
        if let email = env["CAPTURAS_INQUILINO_EMAIL"], !email.isEmpty, let password = env["CAPTURAS_INQUILINO_PASSWORD"] {
            let ri = r.relanzar(email: email, password: password)
            ri.esperar(ri.app.navigationBars["Mi alquiler"])
            ri.esperar(ri.app.navigationBars["Mi alquiler"])
            ri.capturar("12-inquilino-mi-alquiler")
            ri.pestana("Perfil")
            ri.pausa(1)
            ri.capturar("13-inquilino-perfil")
        }
    }
}

extension CapturasUITests {

    @MainActor
    func test4D() throws {
        let r = try Recorrido.iniciar()

        // Inicio
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.pausa(1)
        r.capturar("01-inicio")
        r.app.swipeUp()
        r.pausa(1)
        r.capturar("02-inicio-alertas")
        r.app.swipeUp()
        r.pausa(1)
        r.capturar("03-inicio-actividad")
        r.app.swipeDown()
        r.app.swipeDown()

        // Informe mensual
        r.app.buttons["Informe del mes"].tap()
        r.esperar(r.app.buttons["Imprimir"], timeout: 20)
        r.pausa(2)
        r.capturar("06-informe-mensual")
        r.app.buttons["Cerrar"].tap()

        // Notificaciones
        r.app.buttons["campana"].tap()
        r.esperar(r.app.buttons["filaNotificacion"].firstMatch)
        r.capturar("04-notificaciones")
        r.app.buttons["filaNotificacion"].firstMatch.tap()
        r.pausa(3)
        r.capturar("05-notificacion-abre-su-pantalla")
        r.atras()
        r.atras()

        // Calendario
        r.pestana("Más")
        r.app.buttons["Calendario"].tap()
        r.esperar(r.elemento(contiene: "de octubre").exists ? r.elemento(contiene: "de octubre") : r.elemento(contiene: "1 de"))
        r.pausa(1)
        r.capturar("07-calendario")
        r.app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", 1 de ")).firstMatch.tap()
        r.pausa(1.5)
        r.capturar("08-calendario-dia")
        r.app.swipeDown(velocity: .fast)
        r.pausa(1)

        // Estadísticas
        r.atras()
        r.app.buttons["Estadísticas"].tap()
        r.esperar(r.elemento(contiene: "Tasa de ocupación"))
        r.pausa(1.5)
        r.capturar("09-estadisticas")
        r.app.swipeUp()
        r.pausa(1)
        r.capturar("10-estadisticas-graficos")
    }
}

extension CapturasUITests {

    @MainActor
    func test4E() throws {
        let r = try Recorrido.iniciar()
        r.esperar(r.elemento(contiene: "Cobrado este mes"))

        // Incidencias
        r.pestana("Incidencias")
        r.esperar(r.app.buttons["filaIncidencia"].firstMatch)
        r.capturar("01-incidencias")
        r.app.buttons["filaIncidencia"].firstMatch.swipeRight()
        r.pausa(1)
        r.capturar("02-incidencia-avanzar-deslizando")
        // Deslizar en sentido contrario cierra las acciones; si quedan abiertas, el toque solo las cierra.
        r.app.buttons["filaIncidencia"].firstMatch.swipeLeft()
        r.pausa(1)
        r.app.buttons["filaIncidencia"].firstMatch.tap()
        r.esperar(r.elemento(contiene: "Comunicada el"))
        r.capturar("03-incidencia-detalle")
        r.atras()
        r.app.buttons["Nueva incidencia"].tap()
        r.esperar(r.app.navigationBars["Nueva incidencia"])
        r.capturar("04-incidencia-nueva")
        r.app.buttons["Cancelar"].tap()

        // Detalle de piso
        r.pestana("Pisos")
        r.esperar(r.app.buttons["tarjetaPiso"].firstMatch)
        r.app.buttons["tarjetaPiso"].firstMatch.tap()
        r.esperar(r.elemento(contiene: "Rentabilidad bruta"))
        r.pausa(2)
        r.capturar("05-piso-detalle")
        r.app.swipeUp()
        r.pausa(1)
        r.capturar("06-piso-grafico-flujo")
        r.app.swipeUp()
        r.app.swipeUp()
        r.pausa(1)
        r.capturar("07-piso-contratos-pagos-incidencias")
        r.desplazarHasta(r.app.buttons["editarDatosFinancieros"]).tap()
        r.esperar(r.app.navigationBars["Datos financieros"])
        r.capturar("08-datos-financieros")
        r.app.buttons["Cancelar"].tap()
        r.app.buttons["Exportar PDF"].tap()
        r.esperar(r.app.buttons["Imprimir"], timeout: 20)
        r.pausa(2)
        r.capturar("09-piso-pdf")
        r.app.buttons["Cerrar"].tap()

        // Mapa de todos los pisos
        r.atras()
        r.app.buttons["Mapa"].tap()
        r.pausa(8)
        r.capturar("10-mapa-pisos")

        // PDF de la calculadora
        r.pestana("Más")
        r.app.buttons["Calculadora de rentabilidad"].tap()
        r.esperar(r.app.staticTexts["Rent. bruta"])
        r.pausa(2)
        r.desplazarHasta(r.app.buttons["Ver desglose completo"]).tap()
        r.app.buttons["Exportar PDF"].tap()
        r.esperar(r.app.buttons["Imprimir"], timeout: 10)
        r.pausa(2)
        r.capturar("11-calculadora-pdf")
        r.app.buttons["Cerrar"].tap()

        let env = ProcessInfo.processInfo.environment
        if let email = env["CAPTURAS_INQUILINO_EMAIL"], !email.isEmpty, let password = env["CAPTURAS_INQUILINO_PASSWORD"] {
            let ri = r.relanzar(email: email, password: password)
            ri.esperar(ri.app.navigationBars["Mi alquiler"])
            ri.pestana("Incidencias")
            ri.pausa(2)
            ri.capturar("12-inquilino-incidencias")
            ri.app.buttons["Nueva incidencia"].tap()
            ri.esperar(ri.app.navigationBars["Nueva incidencia"])
            ri.capturar("13-inquilino-nueva-incidencia")
        }
    }

    /// Fase 4F: búsqueda global, usuarios, perfil completo y registro con invitación.
    @MainActor
    func test4F() throws {
        let r = try Recorrido.iniciar()
        r.esperar(r.elemento(contiene: "Cobrado este mes"))

        // Búsqueda global
        r.app.buttons["botonBuscar"].tap()
        r.esperar(r.app.navigationBars["Buscar"])
        r.capturar("02-buscar")
        let campo = r.app.searchFields.firstMatch
        campo.tap()
        campo.typeText("calle")
        r.esperar(r.app.staticTexts["Contratos"])
        r.pausa(1)
        r.capturar("03-buscar-resultados")
        r.app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Calle")).firstMatch.tap()
        r.esperar(r.elemento(contiene: "Rentabilidad bruta"))
        r.pausa(1)
        r.capturar("04-buscar-abre-piso")
        r.atras()
        r.pausa(1)
        r.app.buttons["Cancel"].firstMatch.tapSiExiste()
        r.app.buttons["Cancelar"].firstMatch.tapSiExiste()
        r.atras()

        // Usuarios (admin)
        r.pestana("Más")
        r.desplazarHasta(r.app.buttons["Usuarios"]).tap()
        r.esperar(r.texto(empiezaPor: "Gestor"))
        r.pausa(1)
        r.capturar("05-usuarios")
        r.texto(empiezaPor: "Gestor").swipeLeft()
        r.pausa(1)
        r.capturar("06-usuarios-desactivar-deslizando")
        r.texto(empiezaPor: "Gestor").swipeRight()
        r.pausa(1)
        r.app.buttons["botonNuevoUsuario"].tap()
        r.esperar(r.app.navigationBars["Nuevo usuario"])
        r.capturar("07-usuario-nuevo")
        r.app.buttons["Cancelar"].tap()
        r.atras()

        // Perfil completo
        r.app.buttons["enlacePerfil"].tap()
        r.esperar(r.app.navigationBars["Perfil"])
        r.capturar("08-perfil")
        r.desplazarHasta(r.elemento(contiene: "Incidencias abiertas"))
        r.capturar("09-perfil-estadisticas")
        r.desplazarHasta(r.app.buttons["botonEditarPerfil"]).tap()
        r.esperar(r.app.navigationBars["Editar perfil"])
        r.capturar("10-editar-perfil")
        r.app.buttons["Cancelar"].tap()
        r.desplazarHasta(r.app.buttons["botonCambiarPassword"]).tap()
        r.esperar(r.app.navigationBars["Cambiar contraseña"])
        // Antes de escribir: iOS oculta en las capturas el contenido de los campos de contraseña.
        r.capturar("11-cambiar-password")
        r.app.buttons["Cancelar"].tap()
        r.desplazarHasta(r.app.buttons["enlaceMiActividad"]).tap()
        r.esperar(r.app.navigationBars["Mi actividad"])
        r.pausa(1)
        r.capturar("12-mi-actividad")

        // Registro del inquilino con su código
        r.app.terminate()
        r.app.launchArguments = ["-reiniciarSesion"]
        r.app.launch()
        r.esperar(r.app.buttons["botonTengoCodigo"])
        r.app.buttons["botonTengoCodigo"].tap()
        r.esperar(r.app.navigationBars["Crear mi cuenta"])
        r.capturar("13-registro-inquilino")
    }
}

/// Rediseño premium: una prueba por pantalla, con capturas en docs/capturas/rediseno/<pantalla>.
extension CapturasUITests {

    @MainActor
    func testRedisenoInicio() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.pausa(2)
        r.capturar("01-inicio")
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("02-inicio-grafico-alertas")
        r.app.swipeUp()
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("03-inicio-vencimientos-actividad")
    }

    @MainActor
    func testRedisenoPisosCobros() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))

        r.pestana("Pisos")
        r.esperar(r.app.buttons["tarjetaPiso"].firstMatch)
        r.pausa(1)
        r.capturar("01-pisos")
        r.app.buttons["tarjetaPiso"].firstMatch.tap()
        r.esperar(r.elemento(contiene: "Rentabilidad bruta"))
        r.pausa(2)
        r.capturar("02-piso-detalle")
        r.app.buttons["editarDatosFinancieros"].firstMatch.tap()
        r.esperar(r.app.navigationBars["Datos financieros"])
        r.pausa(1)
        r.capturar("03-datos-financieros")
        r.app.buttons["Cancelar"].tap()
        r.pausa(1)
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("04-piso-grafico-calculo")
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("05-piso-habitaciones")
        r.app.swipeUp()
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("06-piso-contratos-pagos")
        r.atras()
        r.app.buttons["Mapa"].tap()
        r.pausa(8)
        r.capturar("07-mapa-pisos")
        r.atras()

        r.pestana("Cobros")
        r.esperar(r.elemento(contiene: "Cobrado en"))
        r.pausa(1.5)
        r.capturar("08-cobros")
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("09-cobros-pagos")
        r.app.buttons["Registrar pago"].tap()
        r.esperar(r.app.navigationBars["Registrar pago"])
        r.pausa(1)
        r.capturar("10-registrar-pago")
        r.app.buttons["Cancelar"].tap()
    }

    @MainActor
    func testRedisenoContratosInquilinos() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))

        r.pestana("Más")
        r.app.buttons["Contratos"].tap()
        r.esperar(r.app.buttons["filaContrato"].firstMatch)
        r.pausa(1)
        r.capturar("01-contratos")
        r.app.buttons["filaContrato"].firstMatch.tap()
        r.esperar(r.elemento(contiene: "Renta mensual"))
        r.pausa(1)
        r.capturar("02-contrato-detalle")
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("03-contrato-acciones")
        r.atras()
        r.app.buttons["Nuevo contrato"].tap()
        r.esperar(r.app.navigationBars["Nuevo contrato"])
        r.pausa(1)
        r.capturar("04-contrato-nuevo")
        r.app.buttons["Cancelar"].tap()
        r.atras()

        r.app.buttons["Inquilinos"].tap()
        r.esperar(r.app.buttons["filaInquilino"].firstMatch)
        r.pausa(1)
        r.capturar("05-inquilinos")
        r.app.buttons["filaInquilino"].firstMatch.tap()
        r.esperar(r.app.navigationBars["Inquilino"])
        r.pausa(1.5)
        r.capturar("06-inquilino-ficha")
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("07-inquilino-pagos")
        r.atras()
        r.app.buttons["Nuevo inquilino"].tap()
        r.pausa(1.5)
        r.capturar("08-inquilino-nuevo")
        r.app.buttons["Cancelar"].tap()

        r.pestana("Pisos")
        r.esperar(r.app.buttons["tarjetaPiso"].firstMatch)
        r.app.buttons["tarjetaPiso"].firstMatch.tap()
        r.esperar(r.elemento(contiene: "Rentabilidad bruta"))
        r.desplazarHasta(r.app.buttons["enlaceHabitaciones"]).tap()
        r.esperar(r.app.navigationBars["Habitaciones"])
        r.pausa(1.5)
        r.capturar("09-habitaciones")
        r.app.buttons["Añadir"].tap()
        r.pausa(1.5)
        r.capturar("10-habitacion-nueva")
        r.app.buttons["Cancelar"].tap()
    }

    @MainActor
    func testRedisenoCalendarioEstadisticas() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.pestana("Más")
        r.app.buttons["Calendario"].tap()
        r.esperar(r.elemento(contiene: "Cobrado en"))
        r.pausa(1.5)
        r.capturar("01-calendario")
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("02-calendario-leyenda")
        r.app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", 1 de ")).firstMatch.tap()
        r.pausa(1.5)
        r.capturar("03-calendario-dia")
        r.app.swipeDown(velocity: .fast)
        r.pausa(1)
        r.atras()
        r.app.buttons["Estadísticas"].tap()
        r.esperar(r.elemento(contiene: "hasta hoy"))
        r.pausa(2)
        r.capturar("04-estadisticas")
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("05-estadisticas-habitaciones")
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("06-estadisticas-incidencias")
    }

    @MainActor
    func testRedisenoIncidenciasCalculadora() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))

        r.pestana("Incidencias")
        r.esperar(r.app.buttons["filaIncidencia"].firstMatch)
        r.pausa(1)
        r.capturar("01-incidencias")
        r.app.buttons["filaIncidencia"].firstMatch.tap()
        r.esperar(r.elemento(contiene: "Comunicada el"))
        r.pausa(1)
        r.capturar("02-incidencia-detalle")
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("03-incidencia-coste")
        r.atras()
        r.app.buttons["Nueva incidencia"].tap()
        r.esperar(r.app.navigationBars["Nueva incidencia"])
        r.pausa(1)
        r.capturar("04-incidencia-nueva")
        r.app.buttons["Cancelar"].tap()

        r.pestana("Más")
        r.app.buttons["Calculadora de rentabilidad"].tap()
        r.esperar(r.elemento(contiene: "Cash flow previsto"))
        r.pausa(2)
        r.capturar("05-calculadora")
        r.desplazarHasta(r.app.buttons["Ver desglose completo"]).tap()
        r.pausa(2)
        r.capturar("06-calculadora-desglose")
        r.app.swipeUp()
        r.pausa(1.5)
        r.capturar("07-calculadora-detalle")
    }
    @MainActor
    func testRedisenoPerfilUsuarios() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))

        r.app.buttons["campana"].tap()
        r.esperar(r.app.buttons["filaNotificacion"].firstMatch)
        r.pausa(1)
        r.capturar("01-notificaciones")
        r.atras()
        r.app.buttons["botonBuscar"].tap()
        let campo = r.app.searchFields.firstMatch
        r.esperar(campo)
        campo.tap()
        campo.typeText("calle")
        r.esperar(r.app.staticTexts["Contratos"])
        r.pausa(1)
        r.capturar("02-buscar-resultados")
        r.app.buttons["Cancel"].firstMatch.tapSiExiste()
        r.app.buttons["Cancelar"].firstMatch.tapSiExiste()
        r.atras()

        r.pestana("Más")
        r.pausa(1)
        r.capturar("03-mas")
        r.desplazarHasta(r.app.buttons["Usuarios"]).tap()
        r.esperar(r.texto(empiezaPor: "Gestor"))
        r.pausa(1)
        r.capturar("04-usuarios")
        r.app.buttons["botonNuevoUsuario"].tap()
        r.esperar(r.app.navigationBars["Nuevo usuario"])
        r.capturar("05-usuario-nuevo")
        r.app.buttons["Cancelar"].tap()
        r.atras()

        r.app.buttons["enlacePerfil"].tap()
        r.esperar(r.app.navigationBars["Perfil"])
        r.pausa(1)
        r.capturar("06-perfil")
        r.app.buttons["botonDatosCobro"].tap()
        r.esperar(r.app.navigationBars["Datos de cobro"])
        r.capturar("09-datos-cobro")
        r.app.buttons["Cancelar"].tap()
        r.desplazarHasta(r.app.buttons["enlaceMiActividad"])
        r.pausa(1)
        r.capturar("07-perfil-estadisticas")
        r.app.buttons["enlaceMiActividad"].tap()
        r.esperar(r.app.navigationBars["Mi actividad"])
        r.pausa(1)
        r.capturar("08-mi-actividad")
    }
    @MainActor
    func testRedisenoLoginInquilino() throws {
        let r = try Recorrido.iniciar(capturarLogin: true)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))

        let env = ProcessInfo.processInfo.environment
        guard let email = env["CAPTURAS_INQUILINO_EMAIL"], !email.isEmpty,
              let password = env["CAPTURAS_INQUILINO_PASSWORD"] else {
            throw XCTSkip("Faltan CAPTURAS_INQUILINO_EMAIL o CAPTURAS_INQUILINO_PASSWORD")
        }
        let ri = r.relanzar(email: email, password: password)
        ri.esperar(ri.app.navigationBars["Mi alquiler"])
        ri.pausa(1)
        ri.capturar("02-mi-alquiler")
        ri.app.swipeUp()
        ri.pausa(1)
        ri.capturar("03-mi-alquiler-pagos")
        ri.pestana("Perfil")
        ri.esperar(ri.app.navigationBars["Perfil"])
        ri.pausa(1)
        ri.capturar("04-perfil-inquilino")

        ri.app.terminate()
        ri.app.launchArguments = ["-reiniciarSesion"]
        ri.app.launch()
        ri.app.buttons["botonTengoCodigo"].tap()
        ri.esperar(ri.app.navigationBars["Crear mi cuenta"])
        ri.pausa(1)
        ri.capturar("05-registro-inquilino")
    }
    /// Recorrido para el vídeo (ios/scripts/video.sh): sin capturas, con pausas para verlo.
    @MainActor
    func testVideoRecorrido() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.pausa(2.5)
        r.app.swipeUp()
        r.pausa(2)
        r.app.swipeDown()
        r.pausa(1)

        r.pestana("Pisos")
        r.esperar(r.app.buttons["tarjetaPiso"].firstMatch)
        r.pausa(2)
        r.app.buttons["tarjetaPiso"].firstMatch.tap()
        r.esperar(r.elemento(contiene: "Rentabilidad bruta"))
        r.pausa(2)
        r.app.swipeUp()
        r.pausa(2)
        r.atras()

        r.pestana("Cobros")
        r.pausa(2.5)
        r.pestana("Incidencias")
        r.pausa(2.5)

        r.pestana("Más")
        r.pausa(1.5)
        r.app.buttons["Contratos"].tap()
        r.pausa(2.5)
        r.atras()
        r.app.buttons["Calendario"].tap()
        r.pausa(2.5)
        r.atras()
        r.app.buttons["Estadísticas"].tap()
        r.pausa(2.5)
        r.atras()
        r.app.buttons["Calculadora de rentabilidad"].tap()
        r.pausa(2.5)
    }
    @MainActor
    func testFase5Recibos() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.pestana("Cobros")
        let fila = r.desplazarHasta(r.app.buttons["filaPago"].firstMatch)
        r.pausa(1)
        r.capturar("01-cobros-pagos")
        fila.tap()
        r.esperar(r.app.buttons["Cerrar"], timeout: 20)
        r.pausa(2)
        r.capturar("02-recibo-pdf")
        r.app.buttons["Cerrar"].tap()
        r.pausa(1)
        r.app.buttons["filaPago"].firstMatch.press(forDuration: 1.2)
        r.pausa(1)
        r.capturar("03-recibo-menu")
        r.app.buttons["Enviar recibo por email"].tap()
        r.pausa(2)
        r.capturar("04-recibo-envio")
        r.app.buttons["Aceptar"].firstMatch.tapSiExiste()

        let env = ProcessInfo.processInfo.environment
        if let email = env["CAPTURAS_INQUILINO_EMAIL"], !email.isEmpty, let password = env["CAPTURAS_INQUILINO_PASSWORD"] {
            let ri = r.relanzar(email: email, password: password)
            ri.esperar(ri.app.navigationBars["Mi alquiler"])
            let pago = ri.app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "€", "2026")).firstMatch
            ri.desplazarHasta(pago)
            ri.pausa(1)
            ri.capturar("05-inquilino-pagos")
            pago.tap()
            ri.esperar(ri.app.buttons["Cerrar"], timeout: 20)
            ri.pausa(2)
            ri.capturar("06-inquilino-recibo")
        }
    }
    @MainActor
    func testFase5Fianzas() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        // Un contrato distinto en cada modo: la fianza que se crea en claro ya no está "sin añadir" en oscuro.
        let oscuro = ProcessInfo.processInfo.environment["CAPTURAS_DIR"]?.hasSuffix("oscuro") == true
        r.pestana("Más")
        r.app.buttons["Contratos"].tap()
        r.esperar(r.app.buttons["filaContrato"].firstMatch)
        r.app.buttons.matching(identifier: "filaContrato").element(boundBy: oscuro ? 1 : 0).tap()
        r.esperar(r.app.navigationBars["Contrato"])
        r.pausa(1)
        r.desplazarHasta(r.app.buttons["botonAnadirFianza"]).tap()
        r.esperar(r.app.navigationBars["Nueva fianza"])
        r.app.switches["interruptorDepositada"].switches.firstMatch.tap()
        r.pausa(1)
        r.capturar("01-fianza-nueva")
        r.app.buttons["Guardar"].tap()
        r.desplazarHasta(r.app.buttons["botonDevolverFianza"])
        r.pausa(1)
        r.capturar("02-fianza-en-contrato")
        r.app.buttons["botonDevolverFianza"].tap()
        let campo = r.app.textFields["campoImporteDevuelto"]
        r.esperar(campo)
        campo.tap()
        campo.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 14) + "550")
        // Al salir del campo se confirma el importe y aparece el motivo de la retención.
        r.app.staticTexts["Fecha"].tap()
        r.pausa(1)
        let motivo = r.app.descendants(matching: .any).matching(identifier: "campoMotivo").firstMatch
        r.esperar(motivo)
        motivo.tap()
        motivo.typeText("Pintura de la pared")
        r.pausa(1)
        r.capturar("03-fianza-devolucion")

        let env = ProcessInfo.processInfo.environment
        if let email = env["CAPTURAS_INQUILINO_EMAIL"], !email.isEmpty, let password = env["CAPTURAS_INQUILINO_PASSWORD"] {
            let ri = r.relanzar(email: email, password: password)
            ri.esperar(ri.app.navigationBars["Mi alquiler"])
            ri.desplazarHasta(ri.elemento(contiene: "Depósito"))
            ri.pausa(1)
            ri.capturar("04-inquilino-fianza")
        }
    }
    @MainActor
    func testFase5Avisos() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.app.buttons["campana"].tap()
        r.esperar(r.app.navigationBars["Notificaciones"])
        r.pausa(2)
        r.capturar("01-avisos-propietario")

        let env = ProcessInfo.processInfo.environment
        if let email = env["CAPTURAS_INQUILINO_EMAIL"], !email.isEmpty, let password = env["CAPTURAS_INQUILINO_PASSWORD"] {
            let ri = r.relanzar(email: email, password: password)
            ri.esperar(ri.app.navigationBars["Mi alquiler"])
            ri.app.buttons["campana"].tap()
            ri.esperar(ri.app.navigationBars["Notificaciones"])
            ri.pausa(1)
            ri.capturar("02-avisos-inquilino")
        }
    }
    @MainActor
    func testFase5Renta() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.pestana("Más")
        r.app.buttons["Contratos"].tap()
        let natalia = r.app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Natalia")).firstMatch
        r.desplazarHasta(natalia).tap()
        r.esperar(r.app.navigationBars["Contrato"])
        // La propuesta lee el IRAV del INE: la primera vez tarda unos segundos.
        r.pausa(4)
        r.desplazarHasta(r.app.buttons["botonActualizarRenta"])
        r.pausa(1)
        r.capturar("01-renta-propuesta")
        r.app.buttons["botonActualizarRenta"].tap()
        r.esperar(r.app.navigationBars["Actualizar renta"])
        r.pausa(1)
        r.capturar("02-renta-revision")
        r.app.buttons["Cancelar"].tap()
        r.atras()
        r.app.swipeDown()
        r.app.swipeDown()
        let laura = r.app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Laura")).firstMatch
        r.desplazarHasta(laura).tap()
        r.esperar(r.app.navigationBars["Contrato"])
        r.desplazarHasta(r.elemento(contiene: "IRAV (INE)"))
        r.pausa(1)
        r.capturar("03-renta-historial")
    }
    @MainActor
    func testFase5GastosFotos() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.pestana("Pisos")
        r.esperar(r.app.buttons["tarjetaPiso"].firstMatch)
        r.app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Avenida del Puerto")).firstMatch.tap()
        r.esperar(r.elemento(contiene: "Rentabilidad bruta"))
        r.desplazarHasta(r.app.buttons["enlaceGastos"])
        r.pausa(1)
        r.capturar("01-piso-gastos-reales")
        r.app.buttons["enlaceGastos"].tap()
        r.esperar(r.app.buttons["filaGasto"].firstMatch)
        r.pausa(1)
        r.capturar("02-gastos")
        r.app.buttons["botonNuevoGasto"].tap()
        r.esperar(r.app.navigationBars["Nuevo gasto"])
        r.pausa(1)
        r.capturar("03-gasto-nuevo")
        r.app.buttons["Cancelar"].tap()
        r.atras()
        r.desplazarHasta(r.app.buttons["enlaceResumenFiscal"]).tap()
        r.esperar(r.app.navigationBars["Resumen fiscal"])
        r.app.buttons["Año siguiente"].tap()
        r.pausa(2)
        r.capturar("04-resumen-fiscal")
        r.app.swipeUp()
        r.pausa(1)
        r.capturar("05-resumen-fiscal-notas")

        r.pestana("Incidencias")
        r.esperar(r.app.buttons["filaIncidencia"].firstMatch)
        r.app.buttons["filaIncidencia"].firstMatch.tap()
        r.desplazarHasta(r.app.buttons["botonAnadirFotos"])
        r.pausa(2)
        r.capturar("06-incidencia-fotos")

        let env = ProcessInfo.processInfo.environment
        if let email = env["CAPTURAS_INQUILINO_EMAIL"], !email.isEmpty, let password = env["CAPTURAS_INQUILINO_PASSWORD"] {
            let ri = r.relanzar(email: email, password: password)
            ri.esperar(ri.app.navigationBars["Mi alquiler"])
            ri.desplazarHasta(ri.app.buttons["Inventarios de la habitación"]).tap()
            ri.esperar(ri.app.buttons["filaInventario"].firstMatch)
            ri.app.buttons["filaInventario"].firstMatch.tap()
            ri.pausa(2)
            ri.capturar("07-inventario")
            ri.app.swipeUp()
            ri.pausa(1)
            ri.capturar("08-inventario-final")
        }
    }
    @MainActor
    func testFase6() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.pestana("Cobros")
        // Las acciones secundarias van en el botón "•••" de la barra (el último).
        let barra = r.app.navigationBars["Cobros"]
        r.esperar(barra)
        barra.buttons.element(boundBy: barra.buttons.count - 1).tap()
        r.pausa(1)
        r.app.buttons["Conciliar con el banco"].firstMatch.tap()
        r.esperar(r.app.navigationBars["Conciliar con el banco"])
        r.pausa(1)
        r.capturar("01-conciliacion")
        r.app.buttons["Cerrar"].tap()

        r.pestana("Más")
        r.app.buttons["Contratos"].tap()
        let natalia = r.app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Natalia")).firstMatch
        r.desplazarHasta(natalia).tap()
        r.esperar(r.app.navigationBars["Contrato"])
        r.pausa(2)
        let firmar = r.desplazarHasta(r.app.buttons["botonFirmarArrendatario"])
        r.capturar("02-contrato-firma")
        firmar.tap()
        let lienzo = r.app.descendants(matching: .any).matching(identifier: "lienzoFirma").firstMatch
        r.esperar(lienzo)
        let a = lienzo.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.6))
        let b = lienzo.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.3))
        let c = lienzo.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.65))
        a.press(forDuration: 0.1, thenDragTo: b)
        b.press(forDuration: 0.1, thenDragTo: c)
        r.pausa(1)
        r.capturar("03-panel-firma")
        r.app.buttons["Firmar"].tap()
        r.pausa(2)
        r.capturar("04-contrato-firmado-parte")
        r.desplazarHasta(r.app.buttons["botonMensajesContrato"]).tap()
        let campo = r.app.descendants(matching: .any).matching(identifier: "campoMensaje").firstMatch
        r.esperar(campo)
        campo.tap()
        campo.typeText("Hola, Natalia: el viernes pasa el fontanero por la mañana.")
        r.app.buttons["botonEnviarMensaje"].tap()
        r.pausa(2)
        r.capturar("05-chat-propietario")

        let env = ProcessInfo.processInfo.environment
        if let email = env["CAPTURAS_INQUILINO_EMAIL"], !email.isEmpty, let password = env["CAPTURAS_INQUILINO_PASSWORD"] {
            let ri = r.relanzar(email: email, password: password)
            ri.esperar(ri.app.navigationBars["Mi alquiler"])
            ri.pestana("Mensajes")
            ri.esperar(ri.app.buttons["filaConversacion"].firstMatch)
            ri.pausa(1)
            ri.capturar("06-bandeja-inquilino")
            ri.app.buttons["filaConversacion"].firstMatch.tap()
            ri.pausa(2)
            ri.capturar("07-chat-inquilino")
        }
    }
    @MainActor
    func testFase7() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.pestana("Más")
        r.app.buttons["enlaceAsistente"].tap()
        r.esperar(r.app.navigationBars["Asistente"])
        r.pausa(2)
        r.capturar("01-asistente")
    }
}

@MainActor
private extension XCUIElement {
    func tapSiExiste() {
        if exists && isHittable { tap() }
    }
}
