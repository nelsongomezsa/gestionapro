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

        r.esperar(r.elemento(contiene: "Cobrado este mes"))
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
        r.esperar(r.app.staticTexts["Rentabilidad bruta"].firstMatch)
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
        r.esperar(r.elemento(contiene: "Cobrado este mes"))

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
        app.launchArguments = argumentos()
        // La app trabaja con fechas de Madrid: así lo que se ve y lo que se guarda no depende de la hora del Mac.
        app.launchEnvironment["TZ"] = "Europe/Madrid"
        app.launch()

        let r = Recorrido(app: app, carpeta: carpeta)
        let campoEmail = app.textFields["campoEmail"]
        r.esperar(campoEmail)
        if capturarLogin { r.capturar("01-login") }
        r.entrar(email: email, password: password)
        return r
    }

    func esperar(_ elemento: XCUIElement, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(elemento.waitForExistence(timeout: timeout), "No apareció: \(elemento)", file: file, line: line)
    }

    /// Desliza hacia arriba hasta que el elemento se pueda tocar (máx. 8 veces).
    @discardableResult
    func desplazarHasta(_ elemento: XCUIElement) -> XCUIElement {
        var intentos = 0
        // También se sigue si el elemento queda bajo la barra de pestañas (abajo del todo): ahí el toque
        // lo recibiría la barra.
        func bajoLaBarra() -> Bool { elemento.exists && elemento.frame.maxY > app.frame.maxY - 100 }
        while (!(elemento.exists && elemento.isHittable) || bajoLaBarra()) && intentos < 8 {
            if elemento.exists && elemento.isHittable {
                app.swipeUp(velocity: .slow)
            } else {
                app.swipeUp()
            }
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
        app.launchArguments = Self.argumentos()
        // La app trabaja con fechas de Madrid: así lo que se ve y lo que se guarda no depende de la hora del Mac.
        app.launchEnvironment["TZ"] = "Europe/Madrid"
        app.launch()
        esperar(app.textFields["campoEmail"])
        entrar(email: email, password: password)
        return self
    }

    func entrar(email: String, password: String) {
        let campoEmail = app.textFields["campoEmail"]
        campoEmail.tap()
        campoEmail.typeText(email)
        let campoPassword = app.secureTextFields["campoPassword"]
        campoPassword.tap()
        campoPassword.typeText(password)
        app.buttons["botonEntrar"].tap()
    }

    /// CAPTURAS_IDIOMA=en abre la app en inglés.
    static func argumentos() -> [String] {
        var a = ["-reiniciarSesion"]
        if let idioma = ProcessInfo.processInfo.environment["CAPTURAS_IDIOMA"], !idioma.isEmpty {
            a += ["-AppleLanguages", "(\(idioma))", "-AppleLocale", idioma == "en" ? "en_US" : "es_ES"]
        }
        return a
    }

    /// Primera notificación tocable: los avisos del mismo tipo van agrupados y hay que desplegar el grupo.
    func primeraNotificacion() -> XCUIElement {
        let fila = app.buttons["filaNotificacion"].firstMatch
        let grupo = app.descendants(matching: .any).matching(identifier: "grupoNotificaciones").firstMatch
        let limite = Date().addingTimeInterval(15)
        while Date() < limite, !fila.exists, !grupo.exists { pausa(0.5) }
        if !fila.exists, grupo.exists {
            grupo.tap()
            pausa(1)
            // Dentro del grupo las filas heredan su identificador: la primera tras la cabecera es un aviso.
            let delGrupo = app.buttons.matching(identifier: "grupoNotificaciones")
            if delGrupo.count > 1 { return delGrupo.element(boundBy: 1) }
        }
        esperar(fila)
        return fila
    }

    func pestana(_ nombre: String) {
        let boton = app.buttons["pestana:\(nombre)"].firstMatch
        boton.tap()
        // Más guarda su pila (Incidencias, Contratos...): un segundo toque la devuelve a su raíz, como en iOS.
        if nombre == "Más" { pausa(0.5); boton.tap() }
    }

    /// Propietario: Incidencias está en Más (pulsar Más vuelve a su raíz).
    func incidencias() {
        pestana("Más")
        pestana("Más")
        desplazarHasta(app.buttons["enlaceIncidencias"]).tap()
        esperar(app.navigationBars["Incidencias"])
    }

    /// Botón «+» de la barra de pestañas y una opción de su menú.
    func crear(_ opcion: String) {
        app.buttons["botonCrear"].tap()
        let boton = app.buttons["crear-\(opcion)"]
        esperar(boton)
        boton.tap()
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
        r.esperar(r.elemento(contiene: "Cobrado este mes"))

        // Cobros
        r.pestana("Cobros")
        r.esperar(r.texto(empiezaPor: "Pendientes de cobro"))
        r.pausa(1)
        r.capturar("01-cobros")
        r.app.swipeUp()
        r.pausa(1)
        r.capturar("02-cobros-pagos")
        r.app.swipeDown()

        // El botón de cada fila se anuncia como "Registrar pago de <inquilino>".
        r.app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Registrar pago de")).firstMatch.tap()
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
        r.esperar(r.app.navigationBars["Contrato"])
        r.capturar("08-contrato-detalle")

        // Con la actualización de renta y la fianza, los documentos quedan más abajo.
        r.desplazarHasta(r.app.buttons["Contrato de arrendamiento (PDF)"]).tap()
        r.esperar(r.app.buttons["Imprimir"], timeout: 20)
        r.pausa(2)
        r.capturar("09-contrato-pdf")
        r.app.buttons["Cerrar"].tap()

        r.desplazarHasta(r.app.buttons["Enviar recordatorio de pago"]).tap()
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
        let aviso = r.primeraNotificacion()
        r.capturar("04-notificaciones")
        aviso.tap()
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
        r.esperar(r.elemento(contiene: "Habitaciones por estado"))
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
        r.incidencias()
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
        r.app.navigationBars.buttons["Nueva incidencia"].tap()
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
        r.esperar(r.app.staticTexts["Rentabilidad bruta"].firstMatch)
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
        r.app.swipeDown(); r.app.swipeDown()
        r.pausa(1)
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
        r.app.launchArguments = Recorrido.argumentos()
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

        r.incidencias()
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
        r.app.navigationBars.buttons["Nueva incidencia"].tap()
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
        _ = r.primeraNotificacion()
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

        // Tras volver de Usuarios la lista aún se recoloca: se espera antes de tocar Perfil.
        r.pausa(1)
        r.app.buttons["enlacePerfil"].firstMatch.tap()
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
        ri.app.launchArguments = Recorrido.argumentos()
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
        r.incidencias()
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
        // Un pago propio de este mes (al empezar el mes no hay ninguno): se registra desde la app y se borra al final.
        let datos = try XCTUnwrap(DatosPrueba(), "Este recorrido crea datos: lanza capturas.sh con la URL de la API de pruebas y CAPTURAS_DB")
        let antes = try datos.idsPagosDelMes()
        // Se ejecuta aunque el test falle a mitad (un `defer` no llega si XCTest corta el test).
        addTeardownBlock { if let ahora = try? datos.idsPagosDelMes() { datos.borrarPagos(ahora.subtracting(antes)) } }
        r.pestana("Cobros")
        r.desplazarHasta(r.app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Registrar pago de")).firstMatch).tap()
        r.esperar(r.app.navigationBars["Registrar pago"])
        // Guardar se activa cuando llegan los contratos y el importe de la renta.
        let guardar = r.app.buttons["Guardar"]
        let listo = Date().addingTimeInterval(15)
        while Date() < listo, !guardar.isEnabled { r.pausa(0.5) }
        r.capturar("00-registrar-pago-prellenado")
        guardar.tap()
        // El pago llega a la API (y es el que se borrará al final).
        let hasta = Date().addingTimeInterval(10)
        while Date() < hasta, (try? datos.idsPagosDelMes().subtracting(antes).isEmpty) != false { r.pausa(0.5) }
        XCTAssertFalse(try datos.idsPagosDelMes().subtracting(antes).isEmpty, "El pago no se registró")
        r.app.swipeDown()
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

        r.incidencias()
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

        // Contrato nuevo y sin firmar del inquilino de demo (habitación 990): no depende de pasadas anteriores.
        let env = ProcessInfo.processInfo.environment
        var datos = try XCTUnwrap(DatosPrueba(), "Este recorrido crea datos: lanza capturas.sh con la URL de la API de pruebas y CAPTURAS_DB")
        let idInquilino = try DatosPrueba.idInquilino(api: datos.api, email: try XCTUnwrap(env["CAPTURAS_INQUILINO_EMAIL"]),
                                                      password: try XCTUnwrap(env["CAPTURAS_INQUILINO_PASSWORD"]))
        _ = try datos.contratoSinFirmar(idInquilino: idInquilino)
        let creados = datos
        addTeardownBlock { creados.limpiar() }

        r.pestana("Más")
        r.app.buttons["Contratos"].tap()
        let contrato = r.app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Hab. \(DatosPrueba.numeroHabitacion)")).firstMatch
        r.desplazarHasta(contrato).tap()
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
        let enviado = "el viernes pasa el fontanero"
        r.app.buttons["botonEnviarMensaje"].tap()
        r.esperar(r.elemento(contiene: enviado))
        r.capturar("05-chat-propietario")

        if let email = env["CAPTURAS_INQUILINO_EMAIL"], !email.isEmpty, let password = env["CAPTURAS_INQUILINO_PASSWORD"] {
            let ri = r.relanzar(email: email, password: password)
            ri.esperar(ri.app.navigationBars["Mi alquiler"])
            ri.pestana("Mensajes")
            ri.esperar(ri.app.buttons["filaConversacion"].firstMatch)
            ri.pausa(1)
            ri.capturar("06-bandeja-inquilino")
            ri.app.buttons["filaConversacion"].firstMatch.tap()
            ri.esperar(ri.elemento(contiene: enviado))
            ri.capturar("07-chat-inquilino")
        }
    }
    /// Navegación final: «+» a la derecha de las pestañas, Mensajes como pestaña y Cobros hasta el final.
    @MainActor
    func testIngenieroAccesos() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.pausa(1)
        r.capturar("01-inicio")

        r.pestana("Pisos")
        r.app.buttons["botonCrear"].tap()
        r.esperar(r.app.buttons["crear-pago"])
        r.pausa(1)
        r.capturar("02-menu-crear")
        r.app.buttons["crear-pago"].tap()
        r.esperar(r.app.buttons["cobroPendiente"].firstMatch)
        r.capturar("03-cobro-pendientes")
        r.app.buttons["cobroPendiente"].firstMatch.tap()
        r.esperar(r.app.buttons["Guardar"])
        r.app.buttons["Cancelar"].firstMatch.tap()
        r.pausa(1)
        r.app.buttons["Cancelar"].firstMatch.tap()
        r.pausa(1)

        r.crear("gasto")
        r.esperar(r.app.navigationBars["¿De qué piso?"])
        r.app.buttons["Cancelar"].tap()
        r.pausa(1)

        r.crear("mensajeNuevo")
        r.esperar(r.app.buttons["contratoMensajeNuevo"].firstMatch)
        r.app.buttons["contratoMensajeNuevo"].firstMatch.tap()
        r.esperar(r.app.descendants(matching: .any).matching(identifier: "campoMensaje").firstMatch)
        r.capturar("04-mensaje-nuevo-chat")
        r.atras()
        r.app.buttons["Cancelar"].firstMatch.tap()
        r.pausa(1)

        r.pestana("Mensajes")
        r.esperar(r.app.buttons["filaConversacion"].firstMatch)
        r.capturar("05-mensajes")
        r.app.buttons["filaConversacion"].firstMatch.tap()
        r.pausa(1.5)
        r.capturar("06-chat-con-nombre")
        r.atras()
        r.pausa(1)

        r.pestana("Cobros")
        r.esperar(r.texto(empiezaPor: "Pendientes de cobro"))
        for _ in 0..<12 { r.app.swipeUp(velocity: .fast) }
        r.pausa(1.5)
        r.capturar("07-cobros-final-lista")

        r.incidencias()
        r.pausa(1)
        r.capturar("08-incidencias-desde-mas")
    }

    /// Lengüeta del asistente: se ve en el borde, abre el panel (desactivado sin clave) con el contexto
    /// de la pantalla, se cierra deslizando y VoiceOver la anuncia como botón «Asistente».
    @MainActor
    func testFinalLengueta() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        let lengueta = r.app.otherElements["lenguetaAsistente"].exists ? r.app.otherElements["lenguetaAsistente"] : r.app.buttons["lenguetaAsistente"]
        r.esperar(lengueta)
        XCTAssertEqual(lengueta.label, "Asistente")
        r.pausa(1)
        r.capturar("01-lengueta-cerrada")
        lengueta.tap()
        r.esperar(r.app.navigationBars["Asistente"])
        r.pausa(1.5)
        r.capturar("02-lengueta-abierta")
        // Se cierra arrastrando la hoja hacia abajo desde su borde superior.
        let arriba = r.app.navigationBars["Asistente"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        arriba.press(forDuration: 0.1, thenDragTo: r.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        r.pausa(1.5)
        XCTAssertFalse(r.app.navigationBars["Asistente"].exists, "El panel se cierra deslizando")

        r.pestana("Pisos")
        r.app.buttons["tarjetaPiso"].firstMatch.tap()
        r.esperar(r.app.staticTexts["Rentabilidad bruta"].firstMatch)
        lengueta.tap()
        r.esperar(r.app.descendants(matching: .any).matching(identifier: "contextoAsistente").firstMatch)
        r.pausa(1)
        r.capturar("03-lengueta-con-contexto-piso")
    }

    /// Ajustes completo (desde Más y desde Perfil): apariencia con efecto inmediato, texto, notificaciones,
    /// datos, cuenta y acerca de.
    @MainActor
    func testFinalAjustes() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.app.buttons["pestana:Inicio"])
        r.pestana("Más")
        r.desplazarHasta(r.app.buttons["enlaceAjustes"]).tap()
        r.esperar(r.app.descendants(matching: .any).matching(identifier: "selectorApariencia").firstMatch)
        r.pausa(1)
        r.capturar("01-ajustes-arriba")
        r.app.swipeUp()
        r.pausa(1)
        r.capturar("02-ajustes-medio")
        for _ in 0..<4 { r.app.swipeUp() }
        r.pausa(1.5)
        r.capturar("03-ajustes-abajo")
        r.app.swipeDown(); r.app.swipeDown()
        r.pausa(1)

        r.app.buttons["enlaceTexto"].tap()
        r.esperar(r.app.switches["interruptorTamanoSistema"])
        let tamanoSistema = r.app.switches["interruptorTamanoSistema"]
        func pulsarInterruptor(_ e: XCUIElement) {
            let interior = e.switches.firstMatch
            if interior.exists { interior.tap() } else { e.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap() }
        }
        pulsarInterruptor(tamanoSistema)
        r.pausa(1)
        r.capturar("04a-texto-tras-pulsar")
        r.esperar(r.app.sliders["deslizadorTexto"])
        r.app.sliders["deslizadorTexto"].adjust(toNormalizedSliderPosition: 0.75)
        r.pausa(1)
        r.capturar("04-texto")
        pulsarInterruptor(tamanoSistema)
        r.atras()

        r.app.buttons["enlaceNotificaciones"].tap()
        r.pausa(1)
        r.capturar("05-notificaciones")
        r.atras()

        r.desplazarHasta(r.app.buttons["enlaceAcercaDe"]).tap()
        r.pausa(1)
        r.capturar("06-acerca-de")
        r.app.buttons["enlaceLicencias"].tap()
        r.pausa(1)
        r.capturar("07-licencias")
        r.atras(); r.atras()

        // Desde Perfil también se llega.
        r.pestana("Más")
        r.app.buttons["enlacePerfil"].firstMatch.tap()
        r.desplazarHasta(r.app.buttons["enlaceAjustesPerfil"]).tap()
        r.esperar(r.app.descendants(matching: .any).matching(identifier: "selectorApariencia").firstMatch)
    }

    /// Eliminar cuenta con una cuenta de prueba creada por la API (base de pruebas): doble confirmación
    /// y contraseña; al terminar vuelve al login y esa cuenta ya no entra.
    @MainActor
    func testFinalEliminarCuenta() throws {
        let datos = try XCTUnwrap(DatosPrueba(), "Este recorrido crea datos: lanza capturas.sh con la URL de la API de pruebas y CAPTURAS_DB")
        let email = "baja.uitest.\(Int(Date().timeIntervalSince1970))@example.com"
        let password = "Prueba-Baja-\(UUID().uuidString.prefix(8))"
        _ = try DatosPrueba.pedir(datos.api, "POST", "/api/usuarios",
                                  ["nombre": "Cuenta de prueba", "email": email, "password": password, "rol": "PROPIETARIO"], token: datos.token)

        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.app.buttons["pestana:Inicio"])
        _ = r.relanzar(email: email, password: password)
        r.esperar(r.app.buttons["pestana:Más"])
        r.pestana("Más")
        r.desplazarHasta(r.app.buttons["enlaceAjustes"]).tap()
        r.desplazarHasta(r.app.buttons["ajustesEliminarCuenta"]).tap()
        let campo = r.app.secureTextFields["campoPasswordEliminar"]
        r.esperar(campo)
        campo.tap()
        campo.typeText(password)
        r.capturar("01-eliminar-cuenta")
        r.app.buttons["botonEliminarCuenta"].tap()
        r.esperar(r.app.alerts.firstMatch)
        r.capturar("02-confirmacion")
        r.app.alerts.firstMatch.buttons["Eliminar"].tap()
        r.esperar(r.app.textFields["campoEmail"], timeout: 20)
        r.capturar("03-vuelve-al-login")
        // La cuenta ya no entra.
        XCTAssertThrowsError(try DatosPrueba.pedir(datos.api, "POST", "/api/auth/login", ["email": email, "password": password]))
    }

    /// Capturas finales (también en inglés con CAPTURAS_IDIOMA=en): Inicio, Cobros al final de la
    /// lista, Mensajes, lengüeta cerrada y abierta y Ajustes completo. Solo identificadores: sin textos.
    @MainActor
    func testFinalCapturas() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.app.buttons["pestana:Inicio"])
        r.pausa(2.5)
        r.capturar("01-inicio")

        let lengueta = r.app.descendants(matching: .any).matching(identifier: "lenguetaAsistente").firstMatch
        r.esperar(lengueta)
        r.capturar("02-lengueta-cerrada")
        lengueta.tap()
        r.pausa(2)
        r.capturar("03-lengueta-abierta")
        let arriba = r.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        arriba.press(forDuration: 0.1, thenDragTo: r.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99)))
        r.pausa(1.5)

        r.pestana("Cobros")
        r.pausa(2)
        for _ in 0..<14 { r.app.swipeUp(velocity: .fast) }
        r.pausa(2)
        r.capturar("04-cobros-final-de-lista")

        r.pestana("Mensajes")
        r.esperar(r.app.buttons["filaConversacion"].firstMatch)
        r.pausa(1)
        r.capturar("05-mensajes")

        r.pestana("Más")
        r.pausa(1.2)
        r.capturar("06-mas")
        XCTAssertFalse(r.app.buttons["botonCrear"].exists, "Sin «+» en Más")
        r.desplazarHasta(r.app.buttons["enlaceAjustes"]).tap()
        r.esperar(r.app.descendants(matching: .any).matching(identifier: "selectorApariencia").firstMatch)
        XCTAssertFalse(r.app.buttons["botonCrear"].exists, "Sin «+» en Ajustes")
        r.pausa(1)
        r.capturar("06-ajustes-1")
        r.app.swipeUp()
        r.pausa(1.2)
        r.capturar("07-ajustes-2")
        for _ in 0..<4 { r.app.swipeUp() }
        r.pausa(1.5)
        r.capturar("08-ajustes-3-final")
    }

    /// Auditoría automática de accesibilidad (la misma de Accessibility Inspector) en las pantallas
    /// principales. Anota cada problema en el log ("AUDITORIA|pantalla|tipo|descripción") sin cortar el recorrido.
    @MainActor
    func testIngenieroAccesibilidad() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        func auditar(_ pantalla: String) {
            r.pausa(1.5)
            try? r.app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion, .contrast, .elementDetection, .textClipped]) { issue in
                let elemento = issue.element.map { "\($0.elementType.rawValue):\($0.label)" } ?? "-"
                print("AUDITORIA|\(pantalla)|\(issue.auditType.rawValue)|\(issue.compactDescription)|\(elemento)")
                return true
            }
        }
        auditar("Inicio")
        r.pestana("Pisos"); auditar("Pisos")
        r.pestana("Cobros"); auditar("Cobros")
        r.pestana("Más"); auditar("Mas")
        r.pestana("Mensajes")
        r.esperar(r.app.buttons["filaConversacion"].firstMatch)
        auditar("Mensajes")
    }

    /// Tiempo de arranque en frío (métrica de XCTest, 3 iteraciones).
    @MainActor
    func testIngenieroArranque() throws {
        let opciones = XCTMeasureOptions()
        opciones.iterationCount = 3
        measure(metrics: [XCTApplicationLaunchMetric()], options: opciones) {
            let app = XCUIApplication()
            app.launchEnvironment["TZ"] = "Europe/Madrid"
            app.launch()
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
