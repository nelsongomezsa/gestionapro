import Foundation
import Testing
@testable import GestionApPro

@Suite("Inicio, estadísticas, calendario y notificaciones")
struct PanelTests {

    @Test func dashboard() throws {
        let d = try Fixture.decodificar(Dashboard.self, de: "dashboard")
        #expect(d.ocupacion.habitaciones == 30)
        #expect(d.ocupacion.salud == "Ocupación media")
        #expect(d.ocupacion.tono == .aviso)
        #expect(d.ingresosUltimos6Meses.count == 6)
        #expect(d.ingresosUltimos6Meses.map(\.etiqueta) == ["may", "jun", "jul", "ago", "sept", "oct"])
        #expect(d.tendenciaPct != nil)
        // La tendencia dice con qué compara: el mes anterior hasta el mismo día.
        #expect(d.mesComparado == "sept")
        #expect(d.diaComparado == 30)
        #expect(d.cobradoMesAnteriorMismoDia <= d.cobradoMesAnterior)
        #expect(!d.alertas.isEmpty)
        #expect(d.proximosVencimientos.allSatisfy { $0.vencimiento != .normal })
    }

    @Test func primeraMayuscula_soloLaPrimera() {
        #expect(Formato.primeraMayuscula("jueves, 1 de octubre") == "Jueves, 1 de octubre")
        #expect(Formato.primeraMayuscula("") == "")
    }

    @Test func estadisticas() throws {
        let e = try Fixture.decodificar(Estadisticas.self, de: "estadisticas")
        #expect(e.ingresos12Meses.count == 12)
        #expect(e.incidencias6Meses.count == 6)
        #expect(e.ocupacion.alquiladas + e.ocupacion.disponibles + e.ocupacion.mantenimiento == e.ocupacion.habitaciones)
        // La variación anual compara con el año pasado hasta la misma fecha.
        #expect(e.ingresosAnioAnteriorHastaHoy <= e.ingresosAnioAnterior)
        #expect(Calendar(identifier: .gregorian).component(.year, from: e.fechaComparada) == e.anioActual - 1)
    }

    @Test func calendario_cuadriculaQueEmpiezaEnLunes() throws {
        let c = try Fixture.decodificar(Calendario.self, de: "calendario")
        #expect(c.dias.count == 31)
        // El 1 de octubre de 2026 es jueves: tres huecos (lunes, martes, miércoles).
        #expect(c.huecosIniciales == 3)
        #expect(c.dias.contains { $0.estado == .pagado && !$0.pagos.isEmpty })
        #expect(c.dias.filter { $0.estado == .pagado }.allSatisfy { !$0.pagos.isEmpty })
    }

    @Test func notificaciones_conDestinoNavegable() throws {
        let lista = try Fixture.decodificar([Notificacion].self, de: "notificaciones")
        #expect(!lista.isEmpty)
        for n in lista {
            let destino = try #require(n.destino.flatMap(NotificacionesView.destino), "\(n.tipo) sin destino")
            switch (n.tipo, destino) {
            case ("contrato_vence", .contrato), ("pago_pendiente", .contrato),
                 ("incidencia_antigua", .incidencia), ("mantenimiento_largo", .habitacion):
                break
            default:
                Issue.record("Destino inesperado para \(n.tipo): \(destino)")
            }
        }
    }

    @Test func actividad_textosLegibles() {
        #expect(Actividad(id: 1, accion: "REGISTRAR_PAGO", descripcion: nil, fecha: nil).titulo == "Pago registrado")
        #expect(Actividad(id: 2, accion: "LOGIN_API", descripcion: nil, fecha: nil).icono == "person.badge.key")
        // Un código desconocido se muestra legible en vez de en mayúsculas con guiones bajos.
        #expect(Actividad(id: 3, accion: "EXPORTAR_XML", descripcion: nil, fecha: nil).titulo == "Exportar Xml")
    }

    @Test func informe_pideElMesComoParametro() async throws {
        let servidor = ServidorMock { _ in (200, Data("%PDF-1.7".utf8)) }
        let cliente = APIClient(baseURL: urlBase, session: servidor.session, tokens: TokenStoreEnMemoria(token: "t"))
        _ = try await cliente.descargar(Rutas.informeMensual, consulta: [URLQueryItem(name: "mes", value: Mes(anio: 2026, numero: 10).texto)])
        #expect(servidor.peticiones.first?.url?.absoluteString == "http://api.test/api/informes/mensual?mes=2026-10")
    }
}

@Suite("Fechas con zona horaria")
struct FechasConZonaTests {
    /// La API manda las fechas DATETIME con la zona del servidor (antes sin zona: en un
    /// servidor en UTC+10 el móvil mostraba «dentro de 9 horas»).
    @Test(arguments: ["2026-10-30T12:30:00.123456+10:00", "2026-10-30T12:30:00+10:00", "2026-10-30T02:30:00Z"])
    func fechaConZona(_ texto: String) throws {
        let fecha = try #require(JSONCoding.fecha(texto))
        let c = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: fecha)
        #expect((c.day, c.hour, c.minute) == (30, 2, 30))
    }

    @Test("Los avisos del mismo tipo se agrupan, en el orden del más reciente")
    @MainActor
    func gruposDeAvisos() throws {
        let lista = try Fixture.decodificar([Notificacion].self, de: "notificaciones")
        let grupos = NotificacionesView.grupos(lista)
        #expect(grupos.reduce(0) { $0 + $1.avisos.count } == lista.count)
        #expect(Set(grupos.map(\.clave)).count == grupos.count)
        #expect(grupos.first?.tipo == lista.first?.tipo)
        #expect(Notificacion.resumen(tipo: "cobro_vencido", cantidad: 10) == "10 cobros vencidos este mes")
        let septiembre = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
        #expect(Notificacion.resumen(tipo: "pago_pendiente", cantidad: 3, mes: septiembre).hasPrefix("3 pagos pendientes en "))
    }

    @Test("Asistente: respuesta con acciones propuestas")
    func asistente() throws {
        let r = try Fixture.decodificar(ContestacionAsistente.self, de: "asistente")
        #expect(r.acciones.count == 2)
        #expect(r.acciones[0].tipo == .registrarPago)
        #expect(r.acciones[0].datos.cantidad == 450)
        #expect(r.acciones[0].datos.metodoPago == .transferencia)
        #expect(r.acciones[1].tipo == .recordatorio)
        #expect(r.usadosHoy == 3)
    }

    @Test("Widget: el resumen se guarda en el App Group, calcula el progreso y se borra al cerrar sesión")
    func resumenWidget() throws {
        ResumenWidget.borrar()
        #expect(ResumenWidget.leer() == nil)
        ResumenWidget(mes: "octubre", cobrado: 5730, esperado: 11460, pendientes: 10, incidenciasAbiertas: 12,
                      actualizado: .now).guardar()
        let leido = try #require(ResumenWidget.leer())
        #expect(leido.mes == "octubre")
        #expect(abs(leido.progreso - 0.5) < 0.001)
        #expect(ResumenWidget(mes: "x", cobrado: 10, esperado: 0, pendientes: 0, incidenciasAbiertas: 0, actualizado: .now).progreso == 0)
        ResumenWidget.borrar()
        #expect(ResumenWidget.leer() == nil)
    }
}
