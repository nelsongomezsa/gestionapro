import UIKit
import UserNotifications

/// Recordatorios en este iPhone. Las notificaciones locales funcionan sin cuenta de pago de Apple
/// Developer; las push (desde el servidor) quedan preparadas: se pide el token de APNs y se envía a
/// la API, pero sin la capacidad "Push Notifications" firmada el registro falla sin más.
@MainActor
enum AvisosLocales {
    static let clave = "recordatoriosEnEsteiPhone"
    /// Día del mes en que vence la renta (el mismo que la API: LAU art. 17.2).
    static let diaLimite = 7

    static var activados: Bool { UserDefaults.standard.bool(forKey: clave) }

    /// Pide permiso y, si se concede, registra el iPhone para push. Devuelve si hay permiso.
    static func activar() async -> Bool {
        let concedido = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if concedido { UIApplication.shared.registerForRemoteNotifications() }
        return concedido
    }

    static func desactivar() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Propietario: cada mes, el día siguiente al límite, revisar los cobros vencidos; y una semana antes
    /// de que termine cada contrato próximo a vencer.
    static func programarPropietario(vencimientos: [Contrato]) async {
        guard activados else { return }
        let centro = UNUserNotificationCenter.current()
        centro.removeAllPendingNotificationRequests()
        await mensual(id: "cobros-vencidos", dia: diaLimite + 1, titulo: "Cobros del mes",
                      texto: "Hoy es día \(diaLimite + 1): revisa quién no ha pagado la renta.")
        for c in vencimientos.prefix(20) {
            guard let aviso = Calendar.current.date(byAdding: .day, value: -7, to: c.fechaFin), aviso > .now else { continue }
            var cuando = Calendar.current.dateComponents([.year, .month, .day], from: aviso)
            cuando.hour = 9
            let contenido = UNMutableNotificationContent()
            contenido.title = "Un contrato termina en una semana"
            contenido.body = "\(c.inquilino.nombre) · habitación \(c.habitacion.numero), \(c.piso.direccion)"
            contenido.sound = .default
            try? await centro.add(UNNotificationRequest(identifier: "vence-\(c.id)", content: contenido,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: cuando, repeats: false)))
        }
    }

    /// Inquilino: cada mes, tres días antes del límite, recordatorio de la renta.
    static func programarInquilino(renta: Decimal) async {
        guard activados else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        await mensual(id: "pagar-renta", dia: diaLimite - 3, titulo: "Recuerda pagar la renta",
                      texto: "La renta (\(Formato.euros(renta))) vence el día \(diaLimite).")
    }

    private static func mensual(id: String, dia: Int, titulo: String, texto: String) async {
        let contenido = UNMutableNotificationContent()
        contenido.title = titulo
        contenido.body = texto
        contenido.sound = .default
        var cuando = DateComponents()
        cuando.day = dia
        cuando.hour = 9
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: contenido,
                                  trigger: UNCalendarNotificationTrigger(dateMatching: cuando, repeats: true)))
    }
}

/// Recibe el token de APNs y enseña los avisos también con la app abierta.
final class DelegadoApp: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Último token recibido (hexadecimal); la sesión lo envía a la API al conectarse.
    static let claveToken = "tokenAPNs"

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        UserDefaults.standard.set(deviceToken.map { String(format: "%02x", $0) }.joined(), forKey: Self.claveToken)
        NotificationCenter.default.post(name: .tokenPushRecibido, object: nil)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Sin la capacidad Push firmada (cuenta gratuita) llega aquí: los recordatorios locales siguen funcionando.
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

extension Notification.Name {
    static let tokenPushRecibido = Notification.Name("tokenPushRecibido")
}
