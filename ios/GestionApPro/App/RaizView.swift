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

    var body: some View {
        Group {
            if usuario.rol.gestionaPisos {
                TabView {
                    InicioView().tabItem { Label("Inicio", systemImage: "house") }
                    PisosListaView().tabItem { Label("Pisos", systemImage: "building.2") }
                    CobrosView().tabItem { Label("Cobros", systemImage: "eurosign.circle") }
                    IncidenciasView().tabItem { Label("Incidencias", systemImage: "wrench.and.screwdriver") }
                    MasView(usuario: usuario).tabItem { Label("Más", systemImage: "ellipsis.circle") }
                        .badge(buzon.sinLeer)
                }
                // Barra propia sobre las pestañas (no `tabViewBottomAccessory`: con él, tras cerrar una hoja
                // abierta desde una pestaña, la navegación de esa pestaña dejaba de responder).
                .overlay(alignment: .bottom) {
                    BarraAccesos(abierto: $abierto)
                        .padding(.horizontal, Tema.Espacio.s)
                        .fondoCristal(en: .capsule, interactivo: false)
                        .padding(.horizontal, Tema.Espacio.m + 4)
                        .padding(.bottom, 62)
                }
                // Las listas dejan sitio al final para que la barra no tape la última fila.
                .contentMargins(.bottom, 64, for: .scrollContent)
                .overlay { BurbujaAsistente(contexto: pantalla.contexto) { abierto = .asistente } }
                .sheet(item: $abierto, onDismiss: { Task { await buzon.actualizar(con: sesion.api) } }) { hoja($0) }
            } else {
                TabView {
                    MiAlquilerView()
                        .tabItem { Label("Mi alquiler", systemImage: "key") }
                    IncidenciasView()
                        .tabItem { Label("Incidencias", systemImage: "wrench.and.screwdriver") }
                    NavigationStack { ConversacionesView() }
                        .tabItem { Label("Mensajes", systemImage: "bubble.left.and.bubble.right") }
                        .badge(buzon.sinLeer)
                    NavigationStack { PerfilView(usuario: usuario) }
                        .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                }
            }
        }
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
                ChatView(hilo: c.idIncidencia.map { .incidencia($0) } ?? .contrato(c.idContrato))
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
        case .asistente:
            NavigationStack {
                AsistenteView(contexto: pantalla.contexto)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { abierto = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
