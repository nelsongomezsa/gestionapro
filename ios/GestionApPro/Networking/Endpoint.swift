import Foundation

/// Una petición a la API con el tipo de su respuesta.
struct Endpoint<Respuesta: Decodable & Sendable>: Sendable {
    let metodo: String
    let ruta: String
    /// Parámetros de la URL (?piso=1&estado=disponible). Los nil se omiten.
    var consulta: [URLQueryItem] = []
    var cuerpo: Data? = nil
    /// false solo para login/registro: ahí un 401 son credenciales malas, no una sesión caducada.
    var requiereAuth = true
}

private func json(_ valor: some Encodable) -> Data? {
    try? JSONCoding.encoder().encode(valor)
}

extension Endpoint where Respuesta == TokenResponse {
    static func login(email: String, password: String) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/auth/login",
                 cuerpo: json(LoginRequest(email: email, password: password)), requiereAuth: false)
    }
}

extension Endpoint where Respuesta == Usuario {
    static let me = Endpoint(metodo: "GET", ruta: "/api/me")
}

extension Endpoint where Respuesta == [Piso] {
    static let pisos = Endpoint(metodo: "GET", ruta: "/api/pisos")
}

extension Endpoint where Respuesta == Piso {
    static func piso(id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/pisos/\(id)")
    }
}

extension Endpoint where Respuesta == ItpResponse {
    static let itp = Endpoint(metodo: "GET", ruta: "/api/calculadora/itp")
}

extension Endpoint where Respuesta == RentabilidadResponse {
    static func rentabilidad(_ req: RentabilidadRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/calculadora/rentabilidad", cuerpo: json(req))
    }
}

// MARK: Habitaciones

extension Endpoint where Respuesta == [Habitacion] {
    static func habitaciones(piso: Int? = nil, estado: EstadoHabitacion? = nil) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/habitaciones",
                 consulta: [URLQueryItem(name: "piso", value: piso.map(String.init)),
                            URLQueryItem(name: "estado", value: estado?.rawValue)])
    }
}

extension Endpoint where Respuesta == Habitacion {
    static func crearHabitacion(_ req: HabitacionRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/habitaciones", cuerpo: json(req))
    }

    static func actualizarHabitacion(id: Int, _ req: HabitacionRequest) -> Self {
        Endpoint(metodo: "PUT", ruta: "/api/habitaciones/\(id)", cuerpo: json(req))
    }

    static func cambiarEstado(habitacion id: Int, a estado: EstadoHabitacion) -> Self {
        Endpoint(metodo: "PATCH", ruta: "/api/habitaciones/\(id)/estado", cuerpo: json(CambioEstadoRequest(estado: estado)))
    }
}

extension Endpoint where Respuesta == SinContenido {
    static func borrarHabitacion(id: Int) -> Self {
        Endpoint(metodo: "DELETE", ruta: "/api/habitaciones/\(id)")
    }

    static func borrarInquilino(id: Int) -> Self {
        Endpoint(metodo: "DELETE", ruta: "/api/inquilinos/\(id)")
    }
}

// MARK: Inquilinos

extension Endpoint where Respuesta == [Inquilino] {
    static let inquilinos = Endpoint(metodo: "GET", ruta: "/api/inquilinos")
}

extension Endpoint where Respuesta == Inquilino {
    static func inquilino(id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/inquilinos/\(id)")
    }

    static func crearInquilino(_ req: InquilinoRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/inquilinos", cuerpo: json(req))
    }

    static func actualizarInquilino(id: Int, _ req: InquilinoRequest) -> Self {
        Endpoint(metodo: "PUT", ruta: "/api/inquilinos/\(id)", cuerpo: json(req))
    }
}

extension Endpoint where Respuesta == QrPago {
    static func qrPago(inquilino id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/inquilinos/\(id)/qr-pago")
    }
}

extension Endpoint where Respuesta == Invitacion {
    static func invitar(inquilino id: Int) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/inquilinos/\(id)/invitaciones")
    }
}

// MARK: Perfil

extension Endpoint where Respuesta == Usuario {
    static func actualizarPerfil(_ req: ActualizarPerfilRequest) -> Self {
        Endpoint(metodo: "PATCH", ruta: "/api/me", cuerpo: json(req))
    }
}

// MARK: Contratos

extension Endpoint where Respuesta == [Contrato] {
    static func contratos(filtro: FiltroContratos = .todos, piso: Int? = nil, inquilino: Int? = nil) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/contratos",
                 consulta: [URLQueryItem(name: "filtro", value: filtro.rawValue),
                            URLQueryItem(name: "piso", value: piso.map(String.init)),
                            URLQueryItem(name: "inquilino", value: inquilino.map(String.init))])
    }
}

extension Endpoint where Respuesta == Contrato {
    static func contrato(id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/contratos/\(id)")
    }

    static func crearContrato(_ req: ContratoRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/contratos", cuerpo: json(req))
    }

    static func finalizarContrato(id: Int) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/contratos/\(id)/finalizar")
    }
}

enum Rutas {
    static func pdfContrato(_ id: Int) -> String { "/api/contratos/\(id)/pdf" }
    static func reciboPago(_ id: Int) -> String { "/api/pagos/\(id)/recibo" }
}

// MARK: Actualización de renta

extension Endpoint where Respuesta == PropuestaRenta {
    static func propuestaRenta(contrato id: Int, indice: IndiceRenta? = nil) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/contratos/\(id)/actualizacion-renta",
                 consulta: [URLQueryItem(name: "indice", value: indice?.rawValue)])
    }
}

extension Endpoint where Respuesta == HistorialRenta {
    static func confirmarRenta(contrato id: Int, _ req: ConfirmacionRenta) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/contratos/\(id)/actualizacion-renta", cuerpo: json(req))
    }
}

extension Endpoint where Respuesta == [HistorialRenta] {
    static func historialRenta(contrato id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/contratos/\(id)/actualizaciones-renta")
    }
}

// MARK: Mensajes y firmas

/// Hilo de un contrato o de una incidencia (la API resuelve su contrato).
enum HiloMensajes: Hashable, Sendable {
    case contrato(Int)
    case incidencia(Int)

    var ruta: String {
        switch self {
        case let .contrato(id): "/api/contratos/\(id)/mensajes"
        case let .incidencia(id): "/api/incidencias/\(id)/mensajes"
        }
    }
}

extension Rutas {
    static func firmar(contrato id: Int, parte: ParteFirma) -> String { "/api/contratos/\(id)/firmas/\(parte.rawValue)" }
    static func pdfFirmado(_ id: Int) -> String { "/api/contratos/\(id)/pdf-firmado" }
}

extension Endpoint where Respuesta == [Conversacion] {
    static let conversaciones = Endpoint(metodo: "GET", ruta: "/api/conversaciones")
}

extension Endpoint where Respuesta == [MensajeChat] {
    static func mensajes(_ hilo: HiloMensajes) -> Self { Endpoint(metodo: "GET", ruta: hilo.ruta) }
}

extension Endpoint where Respuesta == MensajeChat {
    static func enviarMensaje(_ hilo: HiloMensajes, texto: String) -> Self {
        Endpoint(metodo: "POST", ruta: hilo.ruta, cuerpo: json(MensajeRequest(texto: texto, idIncidencia: nil)))
    }
}

extension Endpoint where Respuesta == EstadoFirmas {
    static func firmas(contrato id: Int) -> Self { Endpoint(metodo: "GET", ruta: "/api/contratos/\(id)/firmas") }
}

// MARK: Asistente

extension Rutas {
    static let leerFactura = "/api/asistente/leer-factura"
}

extension Endpoint where Respuesta == EstadoAsistente {
    static let estadoAsistente = Endpoint(metodo: "GET", ruta: "/api/asistente/estado")
}

extension Endpoint where Respuesta == ContestacionAsistente {
    static func preguntarAsistente(_ p: PreguntaAsistente) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/asistente/conversar", cuerpo: json(p))
    }
}

extension Endpoint where Respuesta == ClasificacionIncidencia {
    static func clasificarIncidencia(_ descripcion: String) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/asistente/clasificar-incidencia", cuerpo: json(["descripcion": descripcion]))
    }
}

// MARK: Conciliación bancaria

extension Rutas {
    static let analizarExtracto = "/api/conciliacion/analizar"
}

extension Endpoint where Respuesta == ConciliacionConfirmada {
    static func confirmarConciliacion(_ req: ConfirmarConciliacion) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/conciliacion/confirmar", cuerpo: json(req))
    }
}

// MARK: Gastos

extension Rutas {
    static func facturaGasto(_ id: Int) -> String { "/api/gastos/\(id)/factura" }
}

extension Endpoint where Respuesta == ResumenGastos {
    static func gastos(piso: Int?, anio: Int?) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/gastos",
                 consulta: [URLQueryItem(name: "piso", value: piso.map(String.init)),
                            URLQueryItem(name: "anio", value: anio.map(String.init))])
    }
}

extension Endpoint where Respuesta == Gasto {
    static func crearGasto(_ req: GastoRequest) -> Self { Endpoint(metodo: "POST", ruta: "/api/gastos", cuerpo: json(req)) }
    static func actualizarGasto(_ id: Int, _ req: GastoRequest) -> Self {
        Endpoint(metodo: "PUT", ruta: "/api/gastos/\(id)", cuerpo: json(req))
    }
}

extension Endpoint where Respuesta == SinContenido {
    static func borrarGasto(_ id: Int) -> Self { Endpoint(metodo: "DELETE", ruta: "/api/gastos/\(id)") }
}

// MARK: Resumen fiscal

extension Rutas {
    static func resumenFiscal(piso id: Int, formato: String) -> String { "/api/pisos/\(id)/resumen-fiscal/\(formato)" }
}

/// Parámetros comunes del resumen fiscal (año y valores catastrales del recibo del IBI).
func consultaResumenFiscal(anio: Int, catastral: Decimal?, construccion: Decimal?) -> [URLQueryItem] {
    [URLQueryItem(name: "anio", value: String(anio)),
     URLQueryItem(name: "valorCatastral", value: catastral.map { "\($0)" }),
     URLQueryItem(name: "valorCatastralConstruccion", value: construccion.map { "\($0)" })]
}

extension Endpoint where Respuesta == ResumenFiscal {
    static func resumenFiscal(piso id: Int, anio: Int, catastral: Decimal?, construccion: Decimal?) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/pisos/\(id)/resumen-fiscal",
                 consulta: consultaResumenFiscal(anio: anio, catastral: catastral, construccion: construccion))
    }
}

// MARK: Fotos e inventarios

extension Rutas {
    static func fotosIncidencia(_ id: Int) -> String { "/api/incidencias/\(id)/fotos" }
    static func fotoIncidencia(_ id: Int) -> String { "/api/incidencias/fotos/\(id)" }
}

extension Rutas {
    static func pdfInventario(_ id: Int) -> String { "/api/inventarios/\(id)/pdf" }
    static func fotoElemento(_ id: Int) -> String { "/api/inventarios/elementos/\(id)/foto" }
}

extension Endpoint where Respuesta == [Inventario] {
    static func inventarios(habitacion id: Int) -> Self { Endpoint(metodo: "GET", ruta: "/api/habitaciones/\(id)/inventarios") }
}

extension Endpoint where Respuesta == Inventario {
    static func crearInventario(habitacion id: Int, _ req: InventarioRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/habitaciones/\(id)/inventarios", cuerpo: json(req))
    }
}

extension Endpoint where Respuesta == SinContenido {
    static func borrarInventario(_ id: Int) -> Self { Endpoint(metodo: "DELETE", ruta: "/api/inventarios/\(id)") }
}

extension Endpoint where Respuesta == [FotoIncidencia] {
    static func fotosIncidencia(_ id: Int) -> Self { Endpoint(metodo: "GET", ruta: Rutas.fotosIncidencia(id)) }
}

extension Endpoint where Respuesta == SinContenido {
    static func borrarFotoIncidencia(_ id: Int) -> Self { Endpoint(metodo: "DELETE", ruta: Rutas.fotoIncidencia(id)) }
}

// MARK: Fianzas

extension Endpoint where Respuesta == Fianza {
    static func fianza(contrato id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/contratos/\(id)/fianza")
    }

    static func guardarFianza(contrato id: Int, _ req: FianzaRequest) -> Self {
        Endpoint(metodo: "PUT", ruta: "/api/contratos/\(id)/fianza", cuerpo: json(req))
    }

    static func devolverFianza(contrato id: Int, _ req: DevolucionFianzaRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/contratos/\(id)/fianza/devolucion", cuerpo: json(req))
    }
}

extension Endpoint where Respuesta == ResumenFianzas {
    static let fianzas = Endpoint(metodo: "GET", ruta: "/api/fianzas")
}

extension Endpoint where Respuesta == EnvioRecibo {
    static func enviarRecibo(pago id: Int) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/pagos/\(id)/recibo/enviar")
    }
}

// MARK: Pagos

extension Endpoint where Respuesta == [Pago] {
    static func pagos(mes: Mes? = nil, inquilino: Int? = nil) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/pagos",
                 consulta: [URLQueryItem(name: "mes", value: mes?.texto),
                            URLQueryItem(name: "inquilino", value: inquilino.map(String.init))])
    }
}

extension Endpoint where Respuesta == ResumenPagos {
    static func resumenPagos(mes: Mes) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/pagos/resumen", consulta: [URLQueryItem(name: "mes", value: mes.texto)])
    }
}

extension Endpoint where Respuesta == Pago {
    static func registrarPago(_ req: PagoRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/pagos", cuerpo: json(req))
    }
}

extension Endpoint where Respuesta == SinContenido {
    static func borrarPago(id: Int) -> Self {
        Endpoint(metodo: "DELETE", ruta: "/api/pagos/\(id)")
    }
}

// MARK: Inicio, estadísticas, calendario y notificaciones

extension Endpoint where Respuesta == Dashboard {
    static let dashboard = Endpoint(metodo: "GET", ruta: "/api/dashboard")
}

extension Endpoint where Respuesta == Estadisticas {
    static let estadisticas = Endpoint(metodo: "GET", ruta: "/api/estadisticas")
}

extension Endpoint where Respuesta == Calendario {
    static func calendario(mes: Mes) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/calendario", consulta: [URLQueryItem(name: "mes", value: mes.texto)])
    }
}

extension Endpoint where Respuesta == [Notificacion] {
    static func notificaciones(soloNoLeidas: Bool = false) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/notificaciones",
                 consulta: [URLQueryItem(name: "soloNoLeidas", value: soloNoLeidas ? "true" : nil)])
    }
}

extension Endpoint where Respuesta == TotalNoLeidas {
    static let notificacionesNoLeidas = Endpoint(metodo: "GET", ruta: "/api/notificaciones/no-leidas")
}

extension Endpoint where Respuesta == Notificacion {
    static func marcarLeida(_ id: Int) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/notificaciones/\(id)/leida")
    }
}

extension Endpoint where Respuesta == TotalMarcadas {
    static let marcarTodasLeidas = Endpoint(metodo: "POST", ruta: "/api/notificaciones/leidas")
}

extension Endpoint where Respuesta == [Actividad] {
    static func actividad(limite: Int = 30) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/actividad", consulta: [URLQueryItem(name: "limite", value: String(limite))])
    }
}

extension Endpoint where Respuesta == Habitacion {
    static func habitacion(id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/habitaciones/\(id)")
    }
}

extension Rutas {
    static let informeMensual = "/api/informes/mensual"
}

// MARK: Incidencias y detalle de piso

extension Endpoint where Respuesta == [Incidencia] {
    static func incidencias(estado: EstadoIncidencia? = nil, piso: Int? = nil) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/incidencias",
                 consulta: [URLQueryItem(name: "estado", value: estado?.rawValue),
                            URLQueryItem(name: "piso", value: piso.map(String.init))])
    }
}

extension Endpoint where Respuesta == Incidencia {
    static func incidencia(id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/incidencias/\(id)")
    }

    static func crearIncidencia(_ req: IncidenciaRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/incidencias", cuerpo: json(req))
    }

    /// Sin estado, avanza un paso (pendiente → en proceso → resuelta).
    static func cambiarEstado(incidencia id: Int, a estado: EstadoIncidencia? = nil) -> Self {
        Endpoint(metodo: "PATCH", ruta: "/api/incidencias/\(id)/estado", cuerpo: json(CambioEstadoIncidencia(estado: estado)))
    }

    static func actualizarIncidencia(id: Int, _ req: ActualizarIncidencia) -> Self {
        Endpoint(metodo: "PATCH", ruta: "/api/incidencias/\(id)", cuerpo: json(req))
    }
}

extension Endpoint where Respuesta == SinContenido {
    static func borrarIncidencia(id: Int) -> Self {
        Endpoint(metodo: "DELETE", ruta: "/api/incidencias/\(id)")
    }
}

extension Endpoint where Respuesta == [ImporteMes] {
    static func ingresosPiso(id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/pisos/\(id)/ingresos")
    }
}

extension Endpoint where Respuesta == Piso {
    static func actualizarPiso(id: Int, _ req: PisoRequest) -> Self {
        Endpoint(metodo: "PUT", ruta: "/api/pisos/\(id)", cuerpo: json(req))
    }
}

extension Endpoint where Respuesta == [Pago] {
    static func pagosDePiso(_ id: Int) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/pagos", consulta: [URLQueryItem(name: "piso", value: String(id))])
    }
}

extension Rutas {
    static func pdfPiso(_ id: Int) -> String { "/api/pisos/\(id)/pdf" }
}

// MARK: Perfil, usuarios, búsqueda y registro (fase 4F)

extension Endpoint where Respuesta == TokenResponse {
    static func registrarInquilino(_ req: RegistroInquilinoRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/auth/register-inquilino", cuerpo: json(req), requiereAuth: false)
    }
}

extension Endpoint where Respuesta == SinContenido {
    static func cambiarPassword(_ req: CambioPasswordRequest) -> Self {
        Endpoint(metodo: "PUT", ruta: "/api/me/password", cuerpo: json(req))
    }
}

extension Endpoint where Respuesta == [Actividad] {
    static func miActividad(limite: Int = 50) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/actividad",
                 consulta: [URLQueryItem(name: "limite", value: String(limite)), URLQueryItem(name: "soloMia", value: "true")])
    }
}

extension Endpoint where Respuesta == [UsuarioAdmin] {
    static let usuarios = Endpoint(metodo: "GET", ruta: "/api/usuarios")
}

extension Endpoint where Respuesta == UsuarioAdmin {
    static func crearUsuario(_ req: NuevoUsuarioRequest) -> Self {
        Endpoint(metodo: "POST", ruta: "/api/usuarios", cuerpo: json(req))
    }

    static func cambiarActivo(usuario id: Int, activo: Bool) -> Self {
        Endpoint(metodo: "PATCH", ruta: "/api/usuarios/\(id)/activo", cuerpo: json(CambioActivoRequest(activo: activo)))
    }

    static func cambiarRol(usuario id: Int, a rol: Rol) -> Self {
        Endpoint(metodo: "PATCH", ruta: "/api/usuarios/\(id)/rol", cuerpo: json(CambioRolRequest(rol: rol)))
    }
}

extension Endpoint where Respuesta == ResultadosBusqueda {
    static func buscar(_ texto: String) -> Self {
        Endpoint(metodo: "GET", ruta: "/api/buscar", consulta: [URLQueryItem(name: "q", value: texto)])
    }
}
