import Foundation

/// Pisos.tipo (V12): qué es el inmueble. Lo que no se reconozca se trata como vivienda.
enum TipoInmueble: String, Codable, CaseIterable, Identifiable, Sendable {
    case vivienda, garajes, trasteros

    var id: Self { self }

    init(from decoder: Decoder) throws {
        let valor = try decoder.singleValueContainer().decode(String.self)
        self = TipoInmueble(rawValue: valor) ?? .vivienda
    }

    /// "Vivienda", "Garaje", "Trasteros" (filtros y selector del alta).
    var nombre: String {
        switch self {
        case .vivienda: String(localized: "Vivienda")
        case .garajes: String(localized: "Garaje")
        case .trasteros: String(localized: "Trasteros")
        }
    }

    /// Para el selector del alta: qué se alquila en cada tipo.
    var descripcion: String {
        switch self {
        case .vivienda: String(localized: "Piso con habitaciones")
        case .garajes: String(localized: "Plazas de garaje (y algún trastero)")
        case .trasteros: String(localized: "Edificio o planta de trasteros")
        }
    }

    /// En la calculadora: qué se compra ("Vivienda", "Plaza de garaje", "Trastero").
    var nombreCompra: String {
        switch self {
        case .vivienda: String(localized: "Vivienda")
        case .garajes: String(localized: "Plaza de garaje")
        case .trasteros: String(localized: "Trastero")
        }
    }

    var icono: String {
        switch self {
        case .vivienda: "house"
        case .garajes: "car"
        case .trasteros: "shippingbox"
        }
    }

    var unidad: TipoUnidad {
        switch self {
        case .vivienda: .habitacion
        case .garajes: .plaza
        case .trasteros: .trastero
        }
    }

    /// Unidades que admite (mismas reglas que la API).
    var unidadesAdmitidas: [TipoUnidad] {
        switch self {
        case .vivienda: [.habitacion]
        case .garajes: [.plaza, .trastero]
        case .trasteros: [.trastero]
        }
    }

    /// Máximo de unidades en el alta (la API admite 50 habitaciones y 500 plazas o trasteros).
    var maximoUnidades: Int { self == .vivienda ? 50 : 500 }
}

/// Habitaciones.tipo (V12): lo que se alquila. Lo que no se reconozca se trata como habitación.
enum TipoUnidad: String, Codable, CaseIterable, Identifiable, Sendable {
    case habitacion, plaza, trastero

    var id: Self { self }

    init(from decoder: Decoder) throws {
        let valor = try decoder.singleValueContainer().decode(String.self)
        self = TipoUnidad(rawValue: valor) ?? .habitacion
    }

    /// "Habitación", "Plaza", "Trastero".
    var nombre: String {
        switch self {
        case .habitacion: String(localized: "Habitación")
        case .plaza: String(localized: "Plaza")
        case .trastero: String(localized: "Trastero")
        }
    }

    /// "Habitaciones", "Plazas", "Trasteros".
    var plural: String {
        switch self {
        case .habitacion: String(localized: "Habitaciones")
        case .plaza: String(localized: "Plazas")
        case .trastero: String(localized: "Trasteros")
        }
    }

    /// "habitaciones", "plazas", "trasteros" (dentro de una frase).
    var pluralMinusculas: String {
        switch self {
        case .habitacion: String(localized: "habitaciones")
        case .plaza: String(localized: "plazas")
        case .trastero: String(localized: "trasteros")
        }
    }

    /// "Hab.", "Plaza", "Trastero" (delante del número en un campo).
    var abreviatura: String {
        switch self {
        case .habitacion: String(localized: "Hab.")
        case .plaza: String(localized: "Plaza")
        case .trastero: String(localized: "Trastero")
        }
    }

    /// "Hab. 3", "Plaza 3", "Trastero 3" (listas).
    func etiqueta(_ numero: Int) -> String {
        switch self {
        case .habitacion: String(localized: "Hab. \(numero)")
        case .plaza: String(localized: "Plaza \(numero)")
        case .trastero: String(localized: "Trastero \(numero)")
        }
    }

    /// "Habitación 3", "Plaza 3", "Trastero 3" (títulos).
    func titulo(_ numero: Int) -> String {
        switch self {
        case .habitacion: String(localized: "Habitación \(numero)")
        case .plaza: String(localized: "Plaza \(numero)")
        case .trastero: String(localized: "Trastero \(numero)")
        }
    }

    /// "Nueva habitación", "Nueva plaza", "Nuevo trastero".
    var nueva: String {
        switch self {
        case .habitacion: String(localized: "Nueva habitación")
        case .plaza: String(localized: "Nueva plaza")
        case .trastero: String(localized: "Nuevo trastero")
        }
    }

    /// "Elige una habitación", "Elige una plaza", "Elige un trastero".
    var elige: String {
        switch self {
        case .habitacion: String(localized: "Elige una habitación")
        case .plaza: String(localized: "Elige una plaza")
        case .trastero: String(localized: "Elige un trastero")
        }
    }

    /// "3 de 5 habitaciones alquiladas", "3 de 5 plazas alquiladas", "3 de 5 trasteros alquilados".
    func alquiladas(_ alquiladas: Int, de total: Int) -> String {
        switch self {
        case .habitacion: String(localized: "\(alquiladas) de \(total) habitaciones alquiladas")
        case .plaza: String(localized: "\(alquiladas) de \(total) plazas alquiladas")
        case .trastero: String(localized: "\(alquiladas) de \(total) trasteros alquilados")
        }
    }

    /// "Habitaciones libres", "Plazas libres", "Trasteros libres".
    var libres: String {
        switch self {
        case .habitacion: String(localized: "Habitaciones libres")
        case .plaza: String(localized: "Plazas libres")
        case .trastero: String(localized: "Trasteros libres")
        }
    }

    /// "Sin habitaciones", "Sin plazas", "Sin trasteros".
    var sinUnidades: String {
        switch self {
        case .habitacion: String(localized: "Sin habitaciones")
        case .plaza: String(localized: "Sin plazas")
        case .trastero: String(localized: "Sin trasteros")
        }
    }

    /// "Este inmueble aún no tiene habitaciones." (y plazas o trasteros).
    var inmuebleSinUnidades: String {
        switch self {
        case .habitacion: String(localized: "Este piso aún no tiene habitaciones.")
        case .plaza: String(localized: "Este garaje aún no tiene plazas.")
        case .trastero: String(localized: "Este inmueble aún no tiene trasteros.")
        }
    }

    /// "Todas (5)" o "Todos (5)".
    func todas(_ n: Int) -> String {
        self == .trastero ? String(localized: "Todos (\(n))") : String(localized: "Todas (\(n))")
    }

    /// "Alquilada hace 3 días" o "Alquilado hace 3 días".
    func alquiladaHace(_ dias: Int) -> String {
        self == .trastero ? String(localized: "Alquilado hace \(dias) días") : String(localized: "Alquilada hace \(dias) días")
    }

    /// "¿Borrar la habitación 3?", "¿Borrar la plaza 3?", "¿Borrar el trastero 3?".
    func borrar(_ numero: Int) -> String {
        switch self {
        case .habitacion: String(localized: "¿Borrar la habitación \(numero)?")
        case .plaza: String(localized: "¿Borrar la plaza \(numero)?")
        case .trastero: String(localized: "¿Borrar el trastero \(numero)?")
        }
    }

    var soloBorrarSinHistorial: String {
        switch self {
        case .habitacion: String(localized: "Solo se pueden borrar habitaciones sin contratos ni incidencias.")
        case .plaza: String(localized: "Solo se pueden borrar plazas sin contratos ni incidencias.")
        case .trastero: String(localized: "Solo se pueden borrar trasteros sin contratos ni incidencias.")
        }
    }

    /// Al finalizar un contrato.
    var quedaDisponible: String {
        switch self {
        case .habitacion: String(localized: "La fecha de fin pasa a ser hoy y la habitación queda disponible.")
        case .plaza: String(localized: "La fecha de fin pasa a ser hoy y la plaza queda disponible.")
        case .trastero: String(localized: "La fecha de fin pasa a ser hoy y el trastero queda disponible.")
        }
    }

    /// "Inventarios de la habitación", "Inventarios de la plaza", "Inventarios del trastero".
    var inventarios: String {
        switch self {
        case .habitacion: String(localized: "Inventarios de la habitación")
        case .plaza: String(localized: "Inventarios de la plaza")
        case .trastero: String(localized: "Inventarios del trastero")
        }
    }

    /// "Gestionar habitaciones", "Gestionar plazas", "Gestionar trasteros".
    var gestionar: String {
        switch self {
        case .habitacion: String(localized: "Gestionar habitaciones")
        case .plaza: String(localized: "Gestionar plazas")
        case .trastero: String(localized: "Gestionar trasteros")
        }
    }

    /// "Precio mensual de cada habitación..." (alta de un inmueble).
    var precioDeCada: String {
        switch self {
        case .habitacion: String(localized: "Precio mensual de cada habitación. Puedes cambiar cualquiera abajo.")
        case .plaza: String(localized: "Precio mensual de cada plaza. Puedes cambiar cualquiera abajo.")
        case .trastero: String(localized: "Precio mensual de cada trastero. Puedes cambiar cualquiera abajo.")
        }
    }

    /// "Número de la habitación", "Número de la plaza", "Número del trastero".
    var numeroDe: String {
        switch self {
        case .habitacion: String(localized: "Número de la habitación")
        case .plaza: String(localized: "Número de la plaza")
        case .trastero: String(localized: "Número del trastero")
        }
    }

    /// "5 habitaciones", "5 plazas", "5 trasteros" (con "1 habitación", etc.).
    func cantidad(_ n: Int) -> String {
        switch self {
        case .habitacion: n == 1 ? String(localized: "1 habitación") : String(localized: "\(n) habitaciones")
        case .plaza: n == 1 ? String(localized: "1 plaza") : String(localized: "\(n) plazas")
        case .trastero: n == 1 ? String(localized: "1 trastero") : String(localized: "\(n) trasteros")
        }
    }

    var icono: String {
        switch self {
        case .habitacion: "bed.double"
        case .plaza: "car"
        case .trastero: "shippingbox"
        }
    }

    /// Elementos que se proponen al hacer un inventario de entrega.
    var elementosInventario: [String] {
        switch self {
        case .habitacion:
            [String(localized: "Cama"), String(localized: "Colchón"), String(localized: "Armario"), String(localized: "Escritorio"),
             String(localized: "Silla"), String(localized: "Paredes"), String(localized: "Suelo"), String(localized: "Ventana"),
             String(localized: "Puerta y cerradura"), String(localized: "Llaves")]
        case .plaza:
            [String(localized: "Mandos de la puerta"), String(localized: "Llaves"), String(localized: "Tarjetas de acceso"),
             String(localized: "Estado de la plaza"), String(localized: "Marcas y numeración")]
        case .trastero:
            [String(localized: "Llaves"), String(localized: "Candado"), String(localized: "Puerta y cerradura"),
             String(localized: "Paredes y suelo"), String(localized: "Iluminación")]
        }
    }

    /// Incidencias típicas, para empezar la descripción con un toque.
    var incidenciasTipicas: [String] {
        switch self {
        case .habitacion:
            [String(localized: "Avería de la caldera"), String(localized: "Fuga de agua"), String(localized: "Cerradura de la puerta")]
        case .plaza:
            [String(localized: "La puerta automática no abre"), String(localized: "Iluminación del garaje fundida"),
             String(localized: "Mando que no funciona"), String(localized: "Humedades o goteras")]
        case .trastero:
            [String(localized: "Humedades en el trastero"), String(localized: "Iluminación fundida"),
             String(localized: "Cerradura o candado roto")]
        }
    }
}

/// Plazas de garaje: para qué vehículo.
enum Vehiculo: String, Codable, CaseIterable, Identifiable, Sendable {
    case coche, moto

    var id: Self { self }

    var nombre: String {
        switch self {
        case .coche: String(localized: "Coche")
        case .moto: String(localized: "Moto")
        }
    }

    var icono: String {
        switch self {
        case .coche: "car.fill"
        case .moto: "bicycle"
        }
    }
}

/// Plural de una cartera: "habitaciones" si solo hay viviendas; "unidades" si hay garajes o trasteros.
enum Unidades {
    static func plural(conOtrosTipos: Bool) -> String {
        conOtrosTipos ? String(localized: "unidades") : String(localized: "habitaciones")
    }

    static func pluralTitulo(conOtrosTipos: Bool) -> String {
        conOtrosTipos ? String(localized: "Unidades") : String(localized: "Habitaciones")
    }
}

/// Modelos que llevan el número y el tipo de su unidad (pagos, cobros, fianzas, inventarios...).
protocol ConUnidad {
    var numeroHabitacion: Int { get }
    var tipoUnidad: TipoUnidad? { get }
}

extension ConUnidad {
    var unidad: TipoUnidad { tipoUnidad ?? .habitacion }
    /// "Hab. 3", "Plaza 3", "Trastero 3".
    var etiquetaUnidad: String { unidad.etiqueta(numeroHabitacion) }
    /// "Habitación 3", "Plaza 3", "Trastero 3".
    var tituloUnidad: String { unidad.titulo(numeroHabitacion) }
}

extension Pago: ConUnidad {}
extension ResumenPagos.Pendiente: ConUnidad {}
extension CobroAtrasado: ConUnidad {}
extension Fianza: ConUnidad {}
extension ContratoBreve: ConUnidad {}
extension Inventario: ConUnidad {}
extension AnalisisConciliacion.Propuesta: ConUnidad {}
