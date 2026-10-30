import Foundation

struct ImporteMes: Decodable, Hashable, Sendable {
    let mes: String
    /// "oct": siempre en español, lo genera la API.
    let etiqueta: String
    let importe: Decimal
}

struct ConteoMes: Decodable, Hashable, Sendable {
    let mes: String
    let etiqueta: String
    let cantidad: Int
}

struct Ocupacion: Decodable, Hashable, Sendable {
    let habitaciones: Int
    let alquiladas: Int
    let disponibles: Int
    let mantenimiento: Int
    /// 66.67 = 66,67 %
    let porcentaje: Double
    /// "Sistema saludable", "Ocupación media" o "Baja ocupación" (umbrales del escritorio).
    let salud: String

    var tono: Tono { porcentaje >= 75 ? .positivo : (porcentaje >= 40 ? .aviso : .negativo) }
}

struct Alerta: Decodable, Hashable, Sendable {
    let tipo: String
    let titulo: String
    let mensaje: String
    /// "aviso" o "negativo"
    let tono: String

    var tonoVisual: Tono { tono == "negativo" ? .negativo : .aviso }

    var icono: String {
        switch tipo {
        case "CONTRATOS_POR_VENCER": "calendar.badge.exclamationmark"
        case "INCIDENCIAS_PENDIENTES": "wrench.and.screwdriver"
        default: "chart.pie"
        }
    }
}

struct Actividad: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let accion: String?
    let descripcion: String?
    let fecha: Date?

    /// Texto legible de los códigos de acción del escritorio y de la API.
    var titulo: String {
        guard let accion else { return "Actividad" }
        return Self.titulos[accion] ?? accion.replacingOccurrences(of: "_", with: " ").capitalized(with: Formato.locale)
    }

    var icono: String {
        guard let accion else { return "clock" }
        if accion.contains("LOGIN") { return "person.badge.key" }
        if accion.contains("PAGO") { return "eurosign.circle" }
        if accion.contains("CONTRATO") { return "doc.text" }
        if accion.contains("INQUILINO") || accion.contains("INVITAR") { return "person.2" }
        if accion.contains("HABITACION") { return "bed.double" }
        if accion.contains("INCIDENCIA") { return "wrench.and.screwdriver" }
        if accion.contains("PISO") { return "building.2" }
        return "clock"
    }

    private static let titulos: [String: String] = [
        "LOGIN": "Inicio de sesión", "LOGIN_API": "Inicio de sesión en la app",
        "CREAR_PISO": "Piso creado", "EDITAR_PISO": "Piso editado", "BORRAR_PISO": "Piso borrado",
        "CREAR_HABITACION": "Habitación creada", "EDITAR_HABITACION": "Habitación editada",
        "BORRAR_HABITACION": "Habitación borrada", "CAMBIAR_ESTADO_HABITACION": "Estado de habitación cambiado",
        "CREAR_INQUILINO": "Inquilino dado de alta", "EDITAR_INQUILINO": "Inquilino editado",
        "BORRAR_INQUILINO": "Inquilino borrado", "INVITAR_INQUILINO": "Invitación enviada",
        "REGISTRO_INQUILINO": "Inquilino registrado en la app",
        "CREAR_CONTRATO": "Contrato creado", "FINALIZAR_CONTRATO": "Contrato finalizado",
        "REGISTRAR_PAGO": "Pago registrado", "BORRAR_PAGO": "Pago borrado",
        "EDITAR_PERFIL": "Perfil actualizado", "CAMBIAR_ROL": "Rol cambiado",
    ]
}

struct Dashboard: Decodable, Sendable {
    let ocupacion: Ocupacion
    let inquilinos: Int
    let contratosActivos: Int
    let incidenciasPendientes: Int
    let incidenciasEnProceso: Int
    let cobradoMes: Decimal
    let cobradoMesAnterior: Decimal
    /// Variación frente al mes anterior en %; nil si el anterior fue 0.
    let tendenciaPct: Double?
    let esperadoMes: Decimal
    let cashFlowMensual: Decimal
    let ingresosUltimos6Meses: [ImporteMes]
    let alertas: [Alerta]
    let proximosVencimientos: [Contrato]
    let actividadReciente: [Actividad]
}

struct Estadisticas: Decodable, Sendable {
    let ingresos12Meses: [ImporteMes]
    let ocupacion: Ocupacion
    let incidencias6Meses: [ConteoMes]
    let ingresosAnioActual: Decimal
    let ingresosAnioAnterior: Decimal
    let variacionAnualPct: Double?
    let anioActual: Int
}

struct Calendario: Decodable, Sendable {
    let mes: String
    let nombreMes: String
    let esperado: Decimal
    let cobrado: Decimal
    let pendiente: Decimal
    let dias: [Dia]

    struct Dia: Decodable, Identifiable, Hashable, Sendable {
        let fecha: Date
        let estado: EstadoDia
        let pagos: [Pago]
        let vencimientos: [Contrato]
        var id: Date { fecha }
    }

    /// Como en el escritorio: pagado, esperado (días 1-5 por llegar), vencido sin cobrar o normal.
    enum EstadoDia: String, Decodable, Sendable {
        case pagado = "PAGADO", esperado = "ESPERADO", vencido = "VENCIDO", normal = "NORMAL"
    }

    /// Huecos antes del día 1 en una cuadrícula que empieza en lunes.
    var huecosIniciales: Int {
        guard let primero = dias.first?.fecha else { return 0 }
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let diaSemana = calendario.component(.weekday, from: primero) // 1 = domingo
        return (diaSemana + 5) % 7
    }
}

struct Notificacion: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let tipo: String
    let titulo: String
    let descripcion: String?
    let fecha: Date
    let leida: Bool
    let destino: Destino?

    struct Destino: Decodable, Hashable, Sendable {
        /// CONTRATO, INCIDENCIA o HABITACION
        let pantalla: String
        let id: Int
    }

    var icono: String {
        switch tipo {
        case "contrato_vence": "calendar.badge.exclamationmark"
        case "pago_pendiente": "eurosign.circle"
        case "incidencia_antigua": "wrench.and.screwdriver"
        case "mantenimiento_largo": "bed.double"
        default: "bell"
        }
    }

    var tono: Tono {
        switch tipo {
        case "pago_pendiente", "incidencia_antigua": .negativo
        case "contrato_vence": .aviso
        default: .neutro
        }
    }
}

struct TotalNoLeidas: Decodable, Sendable { let total: Int }
struct TotalMarcadas: Decodable, Sendable { let marcadas: Int }
