import Foundation
import Observation

/// Alta de un inmueble en tres pasos: tipo y datos básicos, unidades con precio (habitaciones, plazas o
/// trasteros, con m² y planta en los dos últimos) y datos financieros (opcional).
/// Un garaje o trastero suelto va en dos: sus datos están ya en el primero y no hay paso de unidades.
/// Toda la validación está aquí (sin vista) para mostrarla en directo y probarla.
@MainActor
@Observable
final class NuevoPisoViewModel {
    enum Paso: Int, CaseIterable, Sendable {
        case basicos, habitaciones, financieros

        func titulo(_ tipo: TipoInmueble) -> String {
            switch self {
            case .basicos: String(localized: "Datos básicos")
            case .habitaciones: tipo.unidad.plural
            case .financieros: String(localized: "Datos financieros")
            }
        }
    }

    struct HabitacionBorrador: Identifiable, Equatable, Sendable {
        let id = UUID()
        var numero: Int
        var precio: Double
    }

    /// En garajes y trasteros: una unidad comprada por separado o un edificio entero.
    enum Modo: CaseIterable, Sendable {
        case suelta, edificio

        var nombre: String {
            switch self {
            case .suelta: String(localized: "Una unidad suelta")
            case .edificio: String(localized: "Un edificio con varias")
            }
        }

        func descripcion(_ tipo: TipoInmueble) -> String {
            switch (self, tipo) {
            case (.suelta, .trasteros): String(localized: "Un solo trastero, con su compra y sus gastos")
            case (.suelta, _): String(localized: "Una sola plaza, con su compra y sus gastos")
            case (.edificio, .trasteros): String(localized: "Varios trasteros en el mismo inmueble")
            case (.edificio, _): String(localized: "Varias plazas en el mismo inmueble")
            }
        }
    }

    static let maxHabitaciones = TipoInmueble.vivienda.maximoUnidades
    static let maxPrecio = 99_999.99

    var paso: Paso = .basicos
    /// Lo primero que se pregunta: qué se da de alta.
    private(set) var tipo: TipoInmueble = .vivienda
    /// Respuesta a "¿Una unidad suelta o un edificio con varias?"; nil hasta contestarla (y en viviendas).
    private(set) var modo: Modo?
    /// Garajes y trasteros: m² y planta de todas las unidades (opcionales) y, en plazas, para qué vehículo.
    var metros = 0.0
    var planta = ""
    var vehiculo: Vehiculo? = .coche
    var direccion = ""
    private(set) var ciudades: [Piso.Ciudad] = []
    /// Ciudad elegida; nil con "Otra ciudad" (se da de alta con `nuevaCiudad`).
    var idCiudad: Int?
    var otraCiudad = false
    var nuevaCiudad = ""
    private(set) var numeroHabitaciones = 3
    private(set) var habitaciones: [HabitacionBorrador] = []
    var conDatosFinancieros = false
    var datos = DatosFinancierosRequest()
    private(set) var guardando = false
    var error: String?

    init() { ajustarHabitaciones() }

    // MARK: Habitaciones

    /// Cambia el número de habitaciones: añade al final (con el precio de la última) o quita las últimas,
    /// sin tocar las que ya se han editado.
    func cambiarNumero(_ n: Int) {
        numeroHabitaciones = min(max(n, 1), tipo.maximoUnidades)
        ajustarHabitaciones()
    }

    /// Cambia el tipo: un garaje o unos trasteros suelen tener más unidades (10 de partida).
    func cambiarTipo(_ nuevo: TipoInmueble) {
        guard nuevo != tipo else { return }
        tipo = nuevo
        if nuevo == .vivienda { modo = nil }
        guard !esSuelta else { return }
        cambiarNumero(nuevo == .vivienda ? min(numeroHabitaciones, nuevo.maximoUnidades) : max(numeroHabitaciones, 10))
    }

    /// Suelta: una sola unidad y los datos financieros a la vista, que es para lo que se da de alta.
    func elegirModo(_ nuevo: Modo) {
        guard nuevo != modo else { return }
        modo = nuevo
        if nuevo == .suelta {
            cambiarNumero(1)
            conDatosFinancieros = true
        } else {
            cambiarNumero(max(numeroHabitaciones, 10))
        }
    }

    var esSuelta: Bool { tipo != .vivienda && modo == .suelta }

    /// Pasos de este alta: la unidad suelta no tiene paso de unidades.
    var pasos: [Paso] { esSuelta ? [.basicos, .financieros] : Paso.allCases }

    /// El paso anterior o siguiente, si existe.
    func pasoVecino(_ delta: Int) -> Paso? {
        guard let i = pasos.firstIndex(of: paso), pasos.indices.contains(i + delta) else { return nil }
        return pasos[i + delta]
    }

    var errorMetros: String? {
        metros < 0 || metros > 9_999 ? String(localized: "Superficie entre 0 y 9.999 m²") : nil
    }

    var errorPlanta: String? {
        let t = planta.trimmingCharacters(in: .whitespaces)
        if t.count > 20 { return String(localized: "Máximo 20 caracteres") }
        if !t.isEmpty, t.range(of: #"^[\p{L}\p{N} .ºª-]*$"#, options: .regularExpression) == nil {
            return String(localized: "Solo letras, números, espacios y guiones")
        }
        return nil
    }

    private func ajustarHabitaciones() {
        while habitaciones.count < numeroHabitaciones {
            let siguiente = (habitaciones.map(\.numero).max() ?? 0) + 1
            habitaciones.append(HabitacionBorrador(numero: siguiente, precio: habitaciones.last?.precio ?? 0))
        }
        if habitaciones.count > numeroHabitaciones { habitaciones.removeLast(habitaciones.count - numeroHabitaciones) }
    }

    func cambiarPrecio(_ id: UUID, _ precio: Double) {
        guard let i = habitaciones.firstIndex(where: { $0.id == id }) else { return }
        habitaciones[i].precio = precio
    }

    func cambiarNumeroHabitacion(_ id: UUID, _ numero: Int) {
        guard let i = habitaciones.firstIndex(where: { $0.id == id }) else { return }
        habitaciones[i].numero = numero
    }

    /// "Mismo precio para todas".
    func aplicarATodas(_ precio: Double) {
        for i in habitaciones.indices { habitaciones[i].precio = precio }
    }

    // MARK: Validación en directo

    var errorDireccion: String? {
        let t = direccion.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return String(localized: "Escribe la dirección") }
        if t.count > 150 { return String(localized: "Máximo 150 caracteres") }
        return nil
    }

    var errorCiudad: String? {
        if otraCiudad {
            let t = nuevaCiudad.trimmingCharacters(in: .whitespaces)
            if t.count < 2 { return String(localized: "Escribe el nombre de la ciudad") }
            if t.count > 100 { return String(localized: "Máximo 100 caracteres") }
            if t.range(of: #"^\p{L}[\p{L} .'-]*$"#, options: .regularExpression) == nil {
                return String(localized: "Solo letras, espacios y guiones")
            }
            return nil
        }
        return idCiudad == nil ? String(localized: "Elige la ciudad") : nil
    }

    func errorPrecio(_ h: HabitacionBorrador) -> String? {
        if h.precio <= 0 { return String(localized: "Pon un precio mayor que 0") }
        if h.precio > Self.maxPrecio { return String(localized: "Precio demasiado alto") }
        return nil
    }

    func errorNumero(_ h: HabitacionBorrador) -> String? {
        if !(1...999).contains(h.numero) { return String(localized: "Número entre 1 y 999") }
        if habitaciones.filter({ $0.numero == h.numero }).count > 1 { return String(localized: "Número repetido") }
        return nil
    }

    var habitacionesValidas: Bool {
        habitaciones.allSatisfy { errorPrecio($0) == nil && errorNumero($0) == nil }
    }

    func puedeAvanzar(desde paso: Paso) -> Bool {
        switch paso {
        case .basicos:
            errorDireccion == nil && errorCiudad == nil
                && (tipo == .vivienda || (modo != nil && errorMetros == nil && errorPlanta == nil))
                && (!esSuelta || habitacionesValidas)
        case .habitaciones: habitacionesValidas
        case .financieros: true
        }
    }

    var puedeGuardar: Bool { pasos.allSatisfy { puedeAvanzar(desde: $0) } }

    // MARK: Datos

    func cargarCiudades(con api: APIClient) async {
        guard ciudades.isEmpty else { return }
        do {
            ciudades = try await api.enviar(.ciudades)
            if idCiudad == nil, ciudades.isEmpty { otraCiudad = true }
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// La petición que se envía (sin la ciudad nueva, que se da de alta antes).
    func peticion(idCiudad: Int) -> PisoRequest {
        let otro = tipo != .vivienda
        let plantaLimpia = planta.trimmingCharacters(in: .whitespaces)
        return PisoRequest(direccion: direccion.trimmingCharacters(in: .whitespacesAndNewlines),
                    numeroHabitaciones: numeroHabitaciones, idCiudad: idCiudad,
                    datosFinancieros: conDatosFinancieros ? datos : nil,
                    habitaciones: habitaciones.map {
                        PisoRequest.HabitacionInicial(numero: $0.numero,
                                                      precio: Decimal(string: String(format: "%.2f", $0.precio)) ?? 0,
                                                      tipo: otro ? tipo.unidad : nil,
                                                      metros: otro && metros > 0 ? Decimal(string: String(format: "%.2f", metros)) : nil,
                                                      planta: otro && !plantaLimpia.isEmpty ? plantaLimpia : nil,
                                                      vehiculo: tipo == .garajes ? vehiculo : nil)
                    },
                    tipo: tipo)
    }

    /// Da de alta la ciudad si es nueva y crea el piso con sus habitaciones. Devuelve el piso creado.
    func guardar(con api: APIClient) async -> Piso? {
        guard puedeGuardar else { return nil }
        guardando = true
        defer { guardando = false }
        do {
            var ciudad = idCiudad
            if otraCiudad {
                ciudad = try await api.enviar(.crearCiudad(nuevaCiudad.trimmingCharacters(in: .whitespaces))).id
            }
            guard let ciudad else { return nil }
            let piso = try await api.enviar(.crearPiso(peticion(idCiudad: ciudad)))
            Haptica.exito()
            NotificationCenter.default.post(name: .datosCambiados, object: nil)
            return piso
        } catch .noAutorizado {
            return nil
        } catch {
            Haptica.error()
            self.error = error.localizedDescription
            return nil
        }
    }
}
