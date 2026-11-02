import Foundation

/// GET /api/contratos
struct Contrato: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let habitacion: HabitacionBreve
    let piso: PisoBreve
    let inquilino: InquilinoBreve
    let fechaInicio: Date
    let fechaFin: Date
    let precioMensual: Decimal
    let activo: Bool
    let vencimiento: NivelVencimiento
    /// Negativo si ya pasó la fecha de fin.
    let diasRestantes: Int

    struct HabitacionBreve: Decodable, Hashable, Sendable {
        let id: Int
        let numero: Int
    }
}

struct InquilinoBreve: Decodable, Hashable, Sendable {
    let id: Int
    let nombre: String
    let dni: String?
    let telefono: String?
    let email: String?
}

/// Filtro de la lista de contratos: los del escritorio (todos, activos, finalizados) más "por vencer".
enum FiltroContratos: String, CaseIterable, Identifiable, Sendable {
    case activos = "ACTIVOS"
    case porVencer = "POR_VENCER"
    case todos = "TODOS"
    case finalizados = "FINALIZADOS"

    var id: Self { self }

    var nombre: String {
        switch self {
        case .activos: "Activos"
        case .porVencer: "Por vencer"
        case .todos: "Todos"
        case .finalizados: "Finalizados"
        }
    }
}

/// POST /api/contratos
struct ContratoRequest: Encodable, Sendable {
    let idHabitacion: Int
    let idInquilino: Int
    let fechaInicio: String
    let fechaFin: String
    let precioMensual: Decimal
}

/// GET /api/pagos
struct Pago: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let fechaPago: Date
    let cantidad: Decimal
    let metodoPago: MetodoPago
    let idContrato: Int
    let inquilino: InquilinoBreve
    let numeroHabitacion: Int
    let piso: PisoBreve
    /// Número del recibo (2026-0007); nil si aún no se ha emitido (pagos del escritorio).
    var recibo: String? = nil
}

/// POST /api/pagos/{id}/recibo/enviar
struct EnvioRecibo: Decodable, Sendable {
    let enviado: Bool
}

/// POST /api/pagos
struct PagoRequest: Encodable, Sendable {
    let idContrato: Int
    let cantidad: Decimal
    let metodoPago: MetodoPago
    let fechaPago: String
}

/// GET /api/pagos/resumen
struct ResumenPagos: Decodable, Sendable {
    let mes: String
    let nombreMes: String
    let esperado: Decimal
    let cobrado: Decimal
    let pendiente: Decimal
    let numeroPagos: Int
    let pendientes: [Pendiente]

    struct Pendiente: Decodable, Identifiable, Hashable, Sendable {
        let idContrato: Int
        let inquilino: InquilinoBreve
        let numeroHabitacion: Int
        let piso: PisoBreve
        let importe: Decimal
        var id: Int { idContrato }
    }
}

/// GET /api/pagos/atrasados: un mes anterior al actual sin ningún pago de un contrato vigente.
struct CobroAtrasado: Decodable, Identifiable, Hashable, Sendable {
    let idContrato: Int
    let inquilino: InquilinoBreve
    let numeroHabitacion: Int
    let piso: PisoBreve
    /// "2026-09"
    let mes: String
    let nombreMes: String
    let importe: Decimal
    let diasRetraso: Int
    /// false si el contrato ya terminó: la API no deja registrar el pago.
    let contratoActivo: Bool

    var id: String { "\(idContrato)-\(mes)" }

    /// Fecha con la que se registra el pago para que salde ese mes: el último día del mes adeudado.
    /// (Los cobros se cuentan por la fecha del pago; se puede cambiar en el formulario.)
    var fechaParaSaldar: Date? {
        let partes = mes.split(separator: "-").compactMap { Int($0) }
        guard partes.count == 2 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Madrid")!
        guard let inicio = cal.date(from: DateComponents(year: partes[0], month: partes[1], day: 1)),
              let fin = cal.date(byAdding: DateComponents(month: 1, day: -1), to: inicio) else { return nil }
        return cal.date(bySettingHour: 12, minute: 0, second: 0, of: fin)
    }

    /// "Septiembre 2026" con mayúscula.
    var mesTitulo: String { nombreMes.prefix(1).uppercased() + nombreMes.dropFirst() }
}

/// Mes de calendario (aaaa-mm), como espera la API.
struct Mes: Hashable, Comparable, Sendable {
    let anio: Int
    let numero: Int

    static var actual: Mes {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: .now)
        return Mes(anio: c.year!, numero: c.month!)
    }

    var texto: String { String(format: "%04d-%02d", anio, numero) }

    var siguiente: Mes { numero == 12 ? Mes(anio: anio + 1, numero: 1) : Mes(anio: anio, numero: numero + 1) }
    var anterior: Mes { numero == 1 ? Mes(anio: anio - 1, numero: 12) : Mes(anio: anio, numero: numero - 1) }

    /// "Octubre 2026". (El formato de fecha español daría "octubre de 2026".)
    var nombre: String {
        var calendario = Calendar(identifier: .gregorian)
        calendario.locale = Formato.locale
        let mes = calendario.standaloneMonthSymbols[numero - 1]
        return mes.prefix(1).uppercased() + mes.dropFirst() + " \(anio)"
    }

    static func < (a: Mes, b: Mes) -> Bool { (a.anio, a.numero) < (b.anio, b.numero) }
}

enum FechaAPI {
    /// "2026-10-30" en hora de Madrid, el formato LocalDate de la API.
    static func texto(_ fecha: Date) -> String {
        fecha.formatted(Date.ISO8601FormatStyle(timeZone: TimeZone(identifier: "Europe/Madrid")!).year().month().day().dateSeparator(.dash))
    }
}
