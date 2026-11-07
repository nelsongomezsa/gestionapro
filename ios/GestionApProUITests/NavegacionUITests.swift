import XCTest

/// Toca cada enlace y fila tocable de la app y comprueba que abre su pantalla.
/// Necesita la API en marcha y credenciales (las mismas variables que CapturasUITests); sin ellas, se salta.
/// Ejecutar con: ios/scripts/navegacion.sh http://localhost:8081
final class NavegacionUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    /// Toca `boton` (desplazándose hasta él) y espera la barra de navegación `titulo`; después vuelve atrás.
    @MainActor
    private func abre(_ r: Recorrido, _ boton: XCUIElement, barra titulo: String, volver: Bool = true,
                      file: StaticString = #filePath, line: UInt = #line) {
        r.desplazarHasta(boton).tap()
        esperarBarra(r, titulo, file: file, line: line)
        if volver { self.volver(r) }
    }

    /// Vuelve atrás deslizando desde el borde izquierdo (el gesto del sistema): no depende de qué
    /// botón de qué barra encuentre la consulta, como pasaba con "el primer botón de una barra".
    @MainActor
    private func volver(_ r: Recorrido) {
        let inicio = r.app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        inicio.press(forDuration: 0.05, thenDragTo: r.app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        r.pausa(0.8)
    }

    /// Arriba del todo (las tarjetas de Inicio quedan bajo la cabecera si se ha desplazado).
    @MainActor
    private func arriba(_ r: Recorrido) {
        for _ in 0..<5 { r.app.swipeDown(velocity: .fast) }
        r.pausa(0.5)
    }

    /// Sube poco a poco hasta ver `elemento`, sin pasarse: en una pantalla abierta con zoom, deslizar
    /// hacia abajo estando arriba del todo la cierra (gesto del sistema).
    @MainActor
    private func subirHasta(_ r: Recorrido, _ elemento: XCUIElement) {
        var n = 0
        // Visible y por debajo de la barra superior (bajo la barra de cristal el toque no llega).
        func aLaVista() -> Bool { elemento.exists && elemento.isHittable && elemento.frame.minY > r.app.frame.height * 0.15 }
        while !aLaVista() && n < 10 {
            r.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                .press(forDuration: 0.05, thenDragTo: r.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)))
            n += 1
        }
        r.pausa(0.8)
    }

    /// Espera la barra; si no aparece, guarda una captura de lo que hay en pantalla antes de fallar.
    @MainActor
    private func esperarBarra(_ r: Recorrido, _ titulo: String, file: StaticString = #filePath, line: UInt = #line) {
        if !r.app.navigationBars[titulo].waitForExistence(timeout: 15) { r.capturar("fallo-\(titulo)") }
        r.esperar(r.app.navigationBars[titulo], timeout: 1, file: file, line: line)
    }

    @MainActor
    private func detallePiso(_ r: Recorrido) {
        r.esperar(r.app.buttons["enlaceGastos"])
        for (id, barra) in [("enlaceGastos", "Gastos"), ("enlaceResumenFiscal", "Resumen fiscal"), ("enlaceHabitaciones", "Habitaciones")] {
            abre(r, r.app.buttons[id], barra: barra)
            esperarBarra(r, "Piso")
        }
        r.desplazarHasta(r.app.buttons["enlaceMapa"]).tap()
        // El título es la dirección; el mapa depende de la red (puede salir «Dirección no encontrada»).
        r.esperar(r.app.navigationBars.matching(NSPredicate(format: "identifier != %@", "Piso")).firstMatch)
        volver(r)
        esperarBarra(r, "Piso")
        abre(r, r.app.buttons["filaContratoPiso"].firstMatch, barra: "Contrato")
        esperarBarra(r, "Piso")
        let incidencia = r.app.buttons["filaIncidenciaPiso"].firstMatch
        if r.desplazarHasta(incidencia).exists {
            abre(r, incidencia, barra: "Incidencia")
            esperarBarra(r, "Piso")
        }
        subirHasta(r, r.app.buttons["metrica-bruta"])
    }

    @MainActor
    func testEnlacesDelPisoYSusHojas() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        r.pestana("Pisos")
        r.esperar(r.app.buttons["tarjetaPiso"].firstMatch)
        r.app.buttons["tarjetaPiso"].firstMatch.tap()
        detallePiso(r)
        esperarBarra(r, "Piso")

        let titulos = ["bruta": "Rentabilidad bruta", "neta": "Rentabilidad neta", "cashOnCash": "Cash-on-cash", "per": "PER inmobiliario"]
        for metrica in ["bruta", "neta", "cashOnCash", "per"] {
            subirHasta(r, r.app.buttons["metrica-\(metrica)"])
            r.app.buttons["metrica-\(metrica)"].tap()
            // La barra de la hoja (no "Cómo se calcula", que también está en el detalle del piso).
            esperarBarra(r, titulos[metrica]!)
            if metrica == "bruta" {
                // La hoja se presenta con zoom: se espera a que el botón exista antes de desplazarse.
                if !r.app.buttons["simularCalculadora"].waitForExistence(timeout: 10) { r.capturar("fallo-simular") }
                r.desplazarHasta(r.app.buttons["simularCalculadora"]).tap()
                r.esperar(r.app.buttons["guardarAnalisis"])
                volver(r)
            }
            r.app.buttons["Cerrar"].firstMatch.tap()
            r.pausa(0.8)
        }
        r.app.buttons["simularPiso"].tap()
        r.esperar(r.app.buttons["guardarAnalisis"])
        r.app.buttons["Cerrar"].firstMatch.tap()
        r.pausa(0.8)
        volver(r)
        abre(r, r.app.buttons["analizarInversion"], barra: "Calculadora")
    }

    @MainActor
    func testEnlacesDeInicio() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        abre(r, r.app.buttons["kpiContratos"], barra: "Contratos")
        abre(r, r.app.buttons["kpiIncidencias"], barra: "Incidencias")
        arriba(r)
        abre(r, r.app.buttons["botonBuscar"], barra: "Buscar")
        abre(r, r.app.buttons["campana"], barra: "Notificaciones")

        // Ocupación → piso → enlaces del piso (la pila de Inicio también abre las pantallas del piso).
        arriba(r)
        r.app.buttons["kpiOcupacion"].tap()
        esperarBarra(r, "Ocupación")
        r.desplazarHasta(r.app.buttons["filaOcupacionPiso"].firstMatch).tap()
        detallePiso(r)
        volver(r)
        volver(r)

        // Habitaciones libres → ficha → su piso.
        arriba(r)
        r.app.buttons["kpiLibres"].tap()
        r.esperar(r.app.navigationBars["Habitaciones libres"])
        r.app.buttons["filaHabitacionLibre"].firstMatch.tap()
        r.esperar(r.app.buttons["enlacePisoFicha"])
        r.app.buttons["enlacePisoFicha"].tap()
        r.esperar(r.app.buttons["enlaceGastos"])
        abre(r, r.app.buttons["enlaceGastos"], barra: "Gastos")
        volver(r)
        volver(r)
        volver(r)

        for (alerta, barra) in [("COBROS_ATRASADOS", "Cobros atrasados"), ("CONTRATOS_POR_VENCER", "Contratos"),
                                ("INCIDENCIAS_PENDIENTES", "Incidencias")] {
            let boton = r.app.buttons["alerta-\(alerta)"]
            if r.desplazarHasta(boton).exists { abre(r, boton, barra: barra) }
        }
        let vencimiento = r.app.buttons["filaVencimiento"].firstMatch
        if r.desplazarHasta(vencimiento).exists { abre(r, vencimiento, barra: "Contrato") }
        abre(r, r.app.buttons["verActividad"], barra: "Actividad")

        // Tarjeta "Cobrado": mes anterior y, al tocarla, Cobros en ese mes.
        arriba(r)
        r.app.buttons["heroeMesAnterior"].tap()
        let anterior = Self.nombreMesAnterior()
        r.esperar(r.elemento(contiene: anterior))
        // Se toca la propia tarjeta (su cifra): "Pendiente de cobrar" también existe en Cobros.
        r.app.descendants(matching: .any)["heroeInicio"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.15)).tap()
        esperarBarra(r, "Cobros")
        r.esperar(r.app.staticTexts[anterior])
    }

    /// "Octubre 2026": el mes anterior al actual, como lo escribe la app en español.
    static func nombreMesAnterior() -> String {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_ES")
        let fecha = c.date(byAdding: .month, value: -1, to: .now)!
        let m = c.standaloneMonthSymbols[c.component(.month, from: fecha) - 1]
        return m.prefix(1).uppercased() + m.dropFirst() + " \(c.component(.year, from: fecha))"
    }

    @MainActor
    func testEnlacesDeMasYCobros() throws {
        let r = try Recorrido.iniciar(capturarLogin: false)
        r.esperar(r.elemento(contiene: "Cobrado este mes"))
        let secciones: [(String, String, String?, String?)] = [
            ("mas-inquilinos", "Inquilinos", "filaInquilino", "Inquilino"),
            ("mas-contratos", "Contratos", "filaContrato", "Contrato"),
            ("enlaceIncidencias", "Incidencias", "filaIncidencia", "Incidencia"),
            ("mas-calendario", "Calendario", nil, nil),
            ("mas-estadisticas", "Estadísticas", nil, nil),
            ("mas-calculadora", "Calculadora", nil, nil),
            ("enlaceAjustes", "Ajustes", nil, nil),
        ]
        for (id, barra, fila, barraFila) in secciones {
            r.pestana("Más")
            r.desplazarHasta(r.app.buttons[id]).tap()
            r.esperar(r.app.navigationBars[barra])
            if let fila, let barraFila {
                abre(r, r.app.buttons[fila].firstMatch, barra: barraFila)
            }
        }
        r.pestana("Cobros")
        let ver = r.app.buttons["verAtrasados"]
        if r.desplazarHasta(ver).exists { abre(r, ver, barra: "Cobros atrasados") }
    }
}
