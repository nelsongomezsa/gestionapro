import StoreKit
import SwiftUI
import UserNotifications

/// Ajustes, al estilo de los de iOS. Todo se guarda en el iPhone (@AppStorage) salvo la cuenta,
/// que vive en el servidor.
struct AjustesView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.openURL) private var abrirURL
    let usuario: Usuario

    @AppStorage(Apariencia.clave) private var apariencia: Apariencia = .sistema
    @AppStorage(Preferencias.tamanoTexto) private var tamanoTexto = -1
    @AppStorage(Preferencias.negrita) private var negrita = false
    @AppStorage(Preferencias.pestanaInicio) private var pestanaInicio = Pestana.inicio.rawValue
    @AppStorage(BloqueoBiometrico.clave) private var entrarConFaceID = false
    @AppStorage(Preferencias.ocultarEnSelector) private var ocultarEnSelector = true
    @AppStorage(Preferencias.vibracion) private var vibracion = true
    @AppStorage(Preferencias.lengueta) private var lengueta = true
    @State private var confirmarSalida = false
    @State private var hoja: Hoja?
    @State private var cacheVaciada = false

    private enum Hoja: String, Identifiable {
        case password, eliminar
        var id: String { rawValue }
    }

    private var gestiona: Bool { usuario.rol.gestionaPisos }

    var body: some View {
        List {
            Section("Apariencia") {
                Picker("Tema", selection: $apariencia) {
                    ForEach(Apariencia.allCases) { Text(LocalizedStringKey($0.nombre)).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("selectorApariencia")
                NavigationLink {
                    TextoAjustesView()
                } label: {
                    LabeledContent("Texto", value: tamanoTexto < 0 ? String(localized: "Como el iPhone") : String(localized: "Personalizado"))
                }
                .accessibilityIdentifier("enlaceTexto")
            }
            .filaLista()

            Section {
                Picker("Pestaña al abrir", selection: $pestanaInicio) {
                    ForEach(gestiona ? [Pestana.inicio, .pisos, .cobros, .mensajes, .mas] : [.alquiler, .incidencias, .mensajes, .perfil]) {
                        Text($0.nombre).tag($0.rawValue)
                    }
                }
                .accessibilityIdentifier("selectorPestanaInicio")
            } header: {
                Text("General")
            }
            .filaLista()

            Section {
                Toggle(String(localized: "Bloquear con \(BloqueoBiometrico.biometria ?? "Face ID")"), isOn: $entrarConFaceID)
                    .accessibilityIdentifier("interruptorFaceID")
                Toggle("Ocultar en el selector de apps", isOn: $ocultarEnSelector)
                    .accessibilityIdentifier("interruptorOcultarSelector")
            } header: {
                Text("Seguridad")
            } footer: {
                Text("Al abrir la app y al volver a ella se pide \(BloqueoBiometrico.biometria ?? "Face ID") o el código del iPhone. Con «Ocultar», el contenido no se ve al cambiar de app.")
            }
            .filaLista()

            Section {
                NavigationLink { NotificacionesAjustesView(gestiona: gestiona) } label: {
                    Label("Notificaciones", systemImage: "bell.badge")
                }
                .accessibilityIdentifier("enlaceNotificaciones")
                Toggle(isOn: $vibracion) { Label("Vibración", systemImage: "iphone.radiowaves.left.and.right") }
                    .accessibilityIdentifier("interruptorVibracion")
                if gestiona {
                    Toggle(isOn: $lengueta) { Label("Lengüeta del asistente", systemImage: "sparkles") }
                        .accessibilityIdentifier("interruptorLengueta")
                }
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { abrirURL(url) }
                } label: {
                    LabeledContent { Text(Locale.current.localizedString(forLanguageCode: Bundle.main.preferredLocalizations.first ?? "es")?.capitalized ?? "Español") } label: {
                        Label("Idioma", systemImage: "globe")
                    }
                }
                .foregroundStyle(Tema.Color.texto)
                .accessibilityIdentifier("enlaceIdioma")
            } footer: {
                Text("El idioma (español o inglés) se elige en los Ajustes del iPhone, en la página de GestionAp.")
            }
            .filaLista()

            Section("Datos") {
                if gestiona {
                    NavigationLink { ExportarDatosView() } label: { Label("Exportar mis datos", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier("enlaceExportar")
                }
                Button {
                    URLCache.shared.removeAllCachedResponses()
                    try? FileManager.default.contentsOfDirectory(at: FileManager.default.temporaryDirectory, includingPropertiesForKeys: nil)
                        .forEach { try? FileManager.default.removeItem(at: $0) }
                    cacheVaciada = true
                    Haptica.exito()
                } label: {
                    Label(cacheVaciada ? "Caché vaciada" : "Vaciar la caché", systemImage: cacheVaciada ? "checkmark.circle" : "trash")
                }
                .accessibilityIdentifier("botonVaciarCache")
            }
            .filaLista()

            Section("Cuenta") {
                Button { hoja = .password } label: { Label("Cambiar contraseña", systemImage: "key") }
                    .accessibilityIdentifier("ajustesCambiarPassword")
                Button { confirmarSalida = true } label: {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .accessibilityIdentifier("ajustesCerrarSesion")
                Button(role: .destructive) { hoja = .eliminar } label: {
                    Label("Eliminar cuenta", systemImage: "person.crop.circle.badge.xmark").foregroundStyle(Tema.Color.negativo)
                }
                .accessibilityIdentifier("ajustesEliminarCuenta")
            }
            .filaLista()

            Section {
                NavigationLink { AcercaDeView() } label: { Label("Acerca de GestionAp", systemImage: "info.circle") }
                    .accessibilityIdentifier("enlaceAcercaDe")
            }
            .filaLista()
        }
        .estiloLista()
        .navigationTitle("Ajustes")
        .accessibilityIdentifier("pantallaAjustes")
        .sheet(item: $hoja) { h in
            NavigationStack {
                switch h {
                case .password: CambiarPasswordView()
                case .eliminar: EliminarCuentaView()
                }
            }
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmarSalida, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { sesion.cerrarSesion() }
        }
    }
}

extension Pestana {
    var nombre: LocalizedStringKey {
        switch self {
        case .inicio: "Inicio"
        case .pisos: "Pisos"
        case .cobros: "Cobros"
        case .mensajes: "Mensajes"
        case .mas: "Más"
        case .alquiler: "Mi alquiler"
        case .incidencias: "Incidencias"
        case .perfil: "Perfil"
        case .nuevo: "Crear"
        }
    }
}

/// Tamaño del texto dentro de la app (por encima del del iPhone) y negrita, con vista previa.
struct TextoAjustesView: View {
    @AppStorage(Preferencias.tamanoTexto) private var tamanoTexto = -1
    @AppStorage(Preferencias.negrita) private var negrita = false
    private let tamanos = DynamicTypeSize.allCases

    var body: some View {
        List {
            Section {
                Toggle("Usar el tamaño del iPhone", isOn: Binding(
                    get: { tamanoTexto < 0 },
                    set: { tamanoTexto = $0 ? -1 : tamanos.firstIndex(of: .large) ?? 3 }))
                    .accessibilityIdentifier("interruptorTamanoSistema")
                if tamanoTexto >= 0 {
                    HStack {
                        Image(systemName: "textformat.size.smaller").accessibilityHidden(true)
                        Slider(value: Binding(get: { Double(tamanoTexto) }, set: { tamanoTexto = Int($0.rounded()) }),
                               in: 0...Double(tamanos.count - 1), step: 1)
                            .accessibilityLabel("Tamaño del texto")
                            .accessibilityValue("\(tamanoTexto + 1) de \(tamanos.count)")
                            .accessibilityIdentifier("deslizadorTexto")
                        Image(systemName: "textformat.size.larger").accessibilityHidden(true)
                    }
                }
                Toggle("Texto en negrita", isOn: $negrita)
                    .accessibilityIdentifier("interruptorNegrita")
            } footer: {
                Text("Solo cambia el texto de GestionAp; el resto del iPhone sigue igual.")
            }
            .filaLista()

            Section("Vista previa") {
                VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
                    Text("Cobrado este mes").font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.textoSecundario)
                    Text(Formato.euros(Decimal(5730))).font(Tema.Fuente.cifra)
                    Text("Laura Martínez · Hab. 4 · Calle Mayor 15").font(Tema.Fuente.cuerpo)
                }
                .dynamicTypeSize(tamanoTexto >= 0 ? tamanos[min(tamanoTexto, tamanos.count - 1)] : .large)
                .fontWeight(negrita ? .bold : nil)
                .padding(.vertical, Tema.Espacio.xs)
            }
            .filaLista()
        }
        .estiloLista()
        .navigationTitle("Texto")
    }
}

/// Avisos por tipo, día del recordatorio de cobro y enlace a los ajustes del iPhone si están denegados.
struct NotificacionesAjustesView: View {
    @Environment(\.openURL) private var abrirURL
    let gestiona: Bool
    @AppStorage(AvisosLocales.clave) private var recordatorios = false
    @AppStorage(Preferencias.avisosCobros) private var cobros = true
    @AppStorage(Preferencias.avisosIncidencias) private var incidencias = true
    @AppStorage(Preferencias.avisosMensajes) private var mensajes = true
    @AppStorage(Preferencias.avisosContratos) private var contratos = true
    @AppStorage(Preferencias.diaRecordatorio) private var dia = 0
    @State private var denegadas = false

    var body: some View {
        List {
            if denegadas {
                Section {
                    Button {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { abrirURL(url) }
                    } label: {
                        Label("Las notificaciones están desactivadas para GestionAp. Ábrelas en Ajustes del iPhone.", systemImage: "bell.slash")
                    }
                    .accessibilityIdentifier("abrirAjustesNotificaciones")
                }
                .filaLista()
            }
            Section {
                Toggle("Recordatorios en este iPhone", isOn: $recordatorios)
                    .accessibilityIdentifier("interruptorRecordatorios")
                    .onChange(of: recordatorios) { _, activo in
                        Task {
                            if activo {
                                if await AvisosLocales.activar() == false { recordatorios = false; denegadas = true }
                            } else {
                                AvisosLocales.desactivar()
                            }
                        }
                    }
            }
            .filaLista()
            Section {
                Toggle(gestiona ? "Cobros pendientes" : "Pago de la renta", isOn: $cobros)
                if gestiona { Toggle("Contratos por vencer", isOn: $contratos) }
                Toggle("Mensajes nuevos", isOn: $mensajes)
                Toggle("Incidencias", isOn: $incidencias)
                Picker("Día del recordatorio de cobro", selection: $dia) {
                    Text("Automático (día \(gestiona ? AvisosLocales.diaLimite + 1 : AvisosLocales.diaLimite - 3))").tag(0)
                    ForEach(1...28, id: \.self) { Text("Día \($0)").tag($0) }
                }
                .accessibilityIdentifier("selectorDiaRecordatorio")
            } header: {
                Text("Qué avisar")
            } footer: {
                Text("Los cambios se aplican la próxima vez que se abra Inicio. Los avisos de incidencias llegarán como notificaciones push cuando el servidor las tenga activadas; los de mensajes también se muestran dentro de la app.")
            }
            .disabled(!recordatorios)
            .filaLista()
        }
        .estiloLista()
        .navigationTitle("Notificaciones")
        .task {
            let estado = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            denegadas = estado == .denied
        }
    }
}

/// Exporta pisos, cobros y gastos en CSV para compartir o guardar.
struct ExportarDatosView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var archivos: [URL] = []
    @State private var generando = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Button {
                    Task { await generar() }
                } label: {
                    HStack {
                        Label("Generar archivos CSV", systemImage: "tablecells")
                        Spacer()
                        if generando { ProgressView() }
                    }
                }
                .disabled(generando)
                .accessibilityIdentifier("botonGenerarCSV")
                if !archivos.isEmpty {
                    ShareLink(items: archivos) { Label("Compartir o guardar (\(archivos.count) archivos)", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier("compartirExportacion")
                }
            } footer: {
                Text("Pisos, cobros y gastos, separados por punto y coma; se abren en Excel o Numbers.")
            }
            .filaLista()
        }
        .estiloLista()
        .navigationTitle("Exportar mis datos")
        .alertaError($error)
    }

    private func generar() async {
        generando = true
        defer { generando = false }
        do {
            async let p = sesion.api.enviar(.pisos)
            async let c = sesion.api.enviar(.pagos())
            async let g = sesion.api.enviar(.gastos(piso: nil, anio: nil))
            archivos = try ExportarDatos.escribir(pisos: try await p, pagos: try await c, gastos: try await g.lista)
            Haptica.exito()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Eliminar la cuenta: explicación, contraseña y doble confirmación.
struct EliminarCuentaView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    @State private var password = ""
    @State private var confirmar = false
    @State private var eliminando = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                Label("Se borran tu nombre, email, DNI e IBAN y no podrás volver a entrar. Los contratos, pagos y recibos se conservan porque la ley obliga a guardarlos.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Tema.Color.texto)
            }
            .filaLista()
            Section("Confirma con tu contraseña") {
                SecureField("Contraseña", text: $password)
                    .textContentType(.password)
                    .accessibilityIdentifier("campoPasswordEliminar")
            }
            .filaLista()
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                    .filaLista()
            }
            Section {
                Button(role: .destructive) { confirmar = true } label: {
                    HStack {
                        Text("Eliminar mi cuenta")
                        Spacer()
                        if eliminando { ProgressView() }
                    }
                }
                .disabled(password.isEmpty || eliminando)
                .accessibilityIdentifier("botonEliminarCuenta")
            }
            .filaLista()
        }
        .estiloLista()
        .navigationTitle("Eliminar cuenta")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } } }
        .alert("¿Eliminar tu cuenta para siempre?", isPresented: $confirmar) {
            Button("Eliminar", role: .destructive) { Task { await eliminar() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("No se puede deshacer.")
        }
    }

    private func eliminar() async {
        eliminando = true
        defer { eliminando = false }
        do {
            _ = try await sesion.api.enviar(.eliminarCuenta(password: password))
            Haptica.exito()
            sesion.cerrarSesion()
        } catch .noAutorizado {
        } catch {
            Haptica.error()
            password = ""
            self.error = error.localizedDescription
        }
    }
}

/// Versión, privacidad, licencias, soporte y valorar la app.
struct AcercaDeView: View {
    @Environment(\.requestReview) private var pedirValoracion
    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
    private var soporte: String? {
        (Bundle.main.object(forInfoDictionaryKey: "SoporteEmail") as? String).flatMap { $0.contains("@") ? $0 : nil }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Versión", value: version)
                Link(destination: URL(string: "https://github.com/nelsongomezsa/gestionapro/blob/main/docs/PRIVACIDAD.md")!) {
                    Label("Política de privacidad", systemImage: "hand.raised")
                }
                NavigationLink { LicenciasView() } label: { Label("Licencias de terceros", systemImage: "doc.plaintext") }
                    .accessibilityIdentifier("enlaceLicencias")
                if let soporte, let url = URL(string: "mailto:\(soporte)") {
                    Link(destination: url) { Label("Contactar con soporte", systemImage: "envelope") }
                } else {
                    Link(destination: URL(string: "https://github.com/nelsongomezsa/gestionapro/issues")!) {
                        Label("Contactar con soporte", systemImage: "envelope")
                    }
                }
                Button { pedirValoracion() } label: { Label("Valorar la app", systemImage: "star") }
                    .accessibilityIdentifier("botonValorar")
            }
            .filaLista()
        }
        .estiloLista()
        .navigationTitle("Acerca de")
    }
}

/// La app no incluye librerías de terceros; la API sí (se listan con su licencia).
struct LicenciasView: View {
    private let api: [(String, String)] = [
        ("Spring Boot y Spring Framework", "Apache 2.0"), ("Hibernate ORM", "Apache 2.0"), ("Jackson", "Apache 2.0"),
        ("JJWT", "Apache 2.0"), ("MariaDB Connector/J", "LGPL 2.1"), ("iText 7", "AGPL 3.0"),
        ("Bouncy Castle", "MIT"), ("springdoc-openapi", "Apache 2.0"), ("SDK de Anthropic para Java", "MIT"),
    ]

    var body: some View {
        List {
            Section {
                Text("La app de iPhone solo usa frameworks de Apple (SwiftUI, Swift Charts, MapKit, LocalAuthentication, App Intents y WidgetKit).")
            }
            .filaLista()
            Section("Servidor") {
                ForEach(api, id: \.0) { LabeledContent($0.0, value: $0.1) }
            }
            .filaLista()
        }
        .estiloLista()
        .navigationTitle("Licencias")
    }
}
