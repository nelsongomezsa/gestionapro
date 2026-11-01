import SwiftUI

/// Login o pestañas según la sesión y el rol.
struct RaizView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.scenePhase) private var fase
    @AppStorage(Apariencia.clave) private var apariencia: Apariencia = .sistema
    @State private var bloqueo = BloqueoBiometrico()

    var body: some View {
        Group {
            switch sesion.estado {
            case .comprobando:
                ProgressView("Cargando…")
            case .sinSesion:
                LoginView()
            case let .errorAlRestaurar(mensaje):
                ContentUnavailableView {
                    Label("No se pudo conectar", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(mensaje)
                } actions: {
                    Button("Reintentar") { Task { await sesion.restaurar() } }
                        .buttonStyle(.borderedProminent)
                        .tint(Tema.Color.primarioRelleno)
                    Button("Cerrar sesión", role: .destructive) { sesion.cerrarSesion() }
                }
            case let .conectado(usuario) where usuario.debeCambiarPassword == true:
                NavigationStack { CambiarPasswordView(obligatorio: true) }
            case let .conectado(usuario):
                PestanasView(usuario: usuario)
                    .overlay {
                        if bloqueo.bloqueado { PantallaBloqueo(bloqueo: bloqueo).transition(.opacity) }
                    }
            }
        }
        .preferredColorScheme(apariencia.esquema)
        .task {
            bloqueo.bloquearSiProcede()
            await sesion.restaurar()
        }
        .onChange(of: fase) { _, nueva in
            // Al volver de segundo plano se pide otra vez Face ID.
            if nueva == .background { bloqueo.bloquearSiProcede() }
        }
    }
}

/// Propietario y admin: Inicio · Pisos · Cobros · Incidencias · Más, con accesos flotantes.
/// Inquilino: su alquiler y su perfil.
struct PestanasView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.scenePhase) private var fase
    let usuario: Usuario
    @State private var buzon = BuzonMensajes()
    @State private var pantalla = PantallaActual()
    @State private var abierto: AccesoRapido?
    @State private var chat: Conversacion?
    @State private var pendiente = AccionPendiente.compartida
    @AppStorage(BienvenidaView.clave) private var bienvenidaVista = false
    @State private var bienvenida = false

    /// Pestaña elegida (el «+» no es una pestaña: abre el menú de crear).
    @State private var seleccion: Pestana = .inicio
    @State private var creando = false
    @AppStorage(Preferencias.pestanaInicio) private var pestanaInicio = Pestana.inicio.rawValue

    /// Contador por pestaña para volver a su raíz al pulsarla otra vez (se recrea su pila).
    @State private var reinicios: [Pestana: Int] = [:]

    private var items: [ItemPestana] {
        if usuario.rol.gestionaPisos {
            [ItemPestana(pestana: .inicio, titulo: "Inicio", nombre: "Inicio", icono: "house"),
             ItemPestana(pestana: .pisos, titulo: "Pisos", nombre: "Pisos", icono: "building.2"),
             ItemPestana(pestana: .cobros, titulo: "Cobros", nombre: "Cobros", icono: "eurosign.circle"),
             ItemPestana(pestana: .mensajes, titulo: "Mensajes", nombre: "Mensajes", icono: "bubble.left.and.bubble.right", globo: buzon.sinLeer),
             ItemPestana(pestana: .mas, titulo: "Más", nombre: "Más", icono: "ellipsis.circle")]
        } else {
            [ItemPestana(pestana: .alquiler, titulo: "Mi alquiler", nombre: "Mi alquiler", icono: "key"),
             ItemPestana(pestana: .incidencias, titulo: "Incidencias", nombre: "Incidencias", icono: "wrench.and.screwdriver"),
             ItemPestana(pestana: .mensajes, titulo: "Mensajes", nombre: "Mensajes", icono: "bubble.left.and.bubble.right", globo: buzon.sinLeer),
             ItemPestana(pestana: .perfil, titulo: "Perfil", nombre: "Perfil", icono: "person.crop.circle")]
        }
    }

    var body: some View {
        TabView(selection: $seleccion) {
            ForEach(items) { item in
                contenido(de: item.pestana)
                    .id("\(item.pestana.rawValue)-\(reinicios[item.pestana, default: 0])")
                    // La barra del sistema se oculta: solo hay una fila de controles, la propia.
                    .toolbar(.hidden, for: .tabBar)
                    // Hueco invisible del alto de la barra: el último elemento de cada lista queda a la vista.
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear.frame(height: pantalla.sinBarra > 0 ? 0 : BarraPestanas.alto + 6)
                    }
                    .tag(item.pestana)
            }
        }
        .overlay(alignment: .bottom) {
            if pantalla.sinBarra == 0 {
                BarraPestanas(items: items, seleccion: $seleccion,
                              repetir: { reinicios[$0, default: 0] += 1 },
                              crear: { creando = true })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Tema.Movimiento.suave, value: pantalla.sinBarra == 0)
        .onAppear {
            let inicial = Pestana(rawValue: pestanaInicio) ?? .inicio
            seleccion = Pestana.de(inicial, gestiona: usuario.rol.gestionaPisos)
            if let a = pendiente.tomar() { abierto = a }
            else if usuario.rol.gestionaPisos, BienvenidaView.debeMostrarse(vista: bienvenidaVista) { bienvenida = true }
        }
        .sheet(isPresented: $creando) {
            MenuCrear(opciones: usuario.rol.gestionaPisos ? [.pago, .incidencia, .gasto, .mensajeNuevo] : [.incidencia, .mensajeNuevo]) { o in
                creando = false
                // Tras cerrar el menú, se abre la acción elegida.
                Task { try? await Task.sleep(for: .milliseconds(350)); abierto = o }
            }
        }
        .sheet(item: $abierto, onDismiss: { Task { await buzon.actualizar(con: sesion.api) } }) { hoja($0) }
        // Atajos de Siri y Spotlight: abren su hoja al llegar (también si la app estaba cerrada).
        .onChange(of: pendiente.acceso) { _, nuevo in if nuevo != nil { abierto = pendiente.tomar() } }
        .sheet(isPresented: $bienvenida, onDismiss: { bienvenidaVista = true }) { BienvenidaView() }
        .environment(buzon)
        .environment(pantalla)
        .overlay(alignment: .top) {
            if let nueva = buzon.nuevo {
                AvisoMensaje(conversacion: nueva,
                             responder: { chat = nueva; buzon.nuevo = nil },
                             cerrar: { withAnimation(Tema.Movimiento.suave) { buzon.nuevo = nil } })
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: nueva.id) {
                        try? await Task.sleep(for: .seconds(8))
                        withAnimation(Tema.Movimiento.suave) { if buzon.nuevo?.id == nueva.id { buzon.nuevo = nil } }
                    }
            }
        }
        .animation(Tema.Movimiento.suave, value: buzon.nuevo?.id)
        .sheet(item: $chat, onDismiss: { Task { await buzon.actualizar(con: sesion.api) } }) { c in
            NavigationStack {
                ChatView(hilo: c.idIncidencia.map { .incidencia($0) } ?? .contrato(c.idContrato), titulo: c.con)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { chat = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
        // Mensajes nuevos: al abrir, al volver a la app y cada minuto mientras está abierta.
        .task(id: fase) {
            guard fase == .active else { return }
            while !Task.isCancelled {
                await buzon.actualizar(con: sesion.api)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    @ViewBuilder
    private func contenido(de pestana: Pestana) -> some View {
        switch pestana {
        case .inicio: InicioView()
        case .pisos: PisosListaView()
        case .cobros: CobrosView()
        case .mensajes: NavigationStack { ConversacionesView() }
        case .mas: MasView(usuario: usuario)
        case .alquiler: MiAlquilerView()
        case .incidencias: IncidenciasView()
        case .perfil: NavigationStack { PerfilView(usuario: usuario) }
        case .nuevo: EmptyView()
        }
    }

    @ViewBuilder
    private func hoja(_ acceso: AccesoRapido) -> some View {
        switch acceso {
        case .pago:
            CobroRapidoView()
        case .incidencia:
            NuevaIncidenciaView { _ in NotificationCenter.default.post(name: .datosCambiados, object: nil) }
        case .gasto:
            NuevoGastoRapidoView()
        case .mensajes:
            NavigationStack {
                ConversacionesView()
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { abierto = nil } } }
            }
        case .mensajeNuevo:
            if usuario.rol.gestionaPisos {
                NuevoMensajeView()
            } else {
                NavigationStack {
                    ConversacionesView()
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { abierto = nil } } }
                }
            }
        case .asistente:
            NavigationStack {
                AsistenteView(contexto: pantalla.contexto)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { abierto = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
    }
}

/// Pestañas de la app. "nuevo" es el botón «+» (no se queda seleccionado).
enum Pestana: String, CaseIterable, Identifiable {
    case inicio, pisos, cobros, mensajes, mas, alquiler, incidencias, perfil, nuevo
    var id: String { rawValue }

    /// Pestaña de inicio válida para el rol (la del otro rol cae en la primera).
    static func de(_ p: Pestana, gestiona: Bool) -> Pestana {
        let validas: [Pestana] = gestiona ? [.inicio, .pisos, .cobros, .mensajes, .mas] : [.alquiler, .incidencias, .mensajes, .perfil]
        return validas.contains(p) ? p : validas[0]
    }
}

/// Claves de las preferencias que se guardan en el iPhone.
enum Preferencias {
    static let pestanaInicio = "ajustes.pestanaInicio"
}
