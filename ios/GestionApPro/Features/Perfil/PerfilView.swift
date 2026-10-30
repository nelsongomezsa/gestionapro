import SwiftUI

/// Destinos que se abren desde el perfil.
enum DestinoPerfil: Hashable {
    case actividad
}

/// Perfil del escritorio: datos de la cuenta, editar nombre y email, cambiar contraseña,
/// datos de cobro, mis estadísticas e historial de actividad.
struct PerfilView: View {
    @Environment(SesionStore.self) private var sesion
    let usuario: Usuario
    @State private var confirmarSalida = false
    @State private var hoja: Hoja?
    @State private var resumen: Dashboard?
    @AppStorage(Apariencia.clave) private var apariencia: Apariencia = .sistema

    private enum Hoja: String, Identifiable {
        case editar, password, cobro
        var id: String { rawValue }
    }

    /// El usuario al día tras editarlo (la vista recibe el de la sesión al abrirse).
    private var actual: Usuario { sesion.usuario ?? usuario }

    var body: some View {
        List {
            Section {
                VStack(spacing: Tema.Espacio.s) {
                    AvatarIniciales(nombre: actual.nombre, tamano: 84)
                    VStack(spacing: Tema.Espacio.xxs) {
                        Text(actual.nombre).font(Tema.Fuente.titulo)
                        Text(actual.email).foregroundStyle(Tema.Color.textoSecundario)
                    }
                    InsigniaEstado(texto: actual.rol.nombreVisible, tono: .primario, icono: "person.badge.shield.checkmark")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tema.Espacio.s)
                .listRowBackground(Color.clear)
            }

            Section("Cuenta") {
                LabeledContent("Nombre", value: actual.nombre)
                LabeledContent("Email", value: actual.email)
                LabeledContent("Rol", value: actual.rol.nombreVisible)
                Button { hoja = .editar } label: { Label("Editar nombre y email", systemImage: "pencil") }
                    .accessibilityIdentifier("botonEditarPerfil")
                Button { hoja = .password } label: { Label("Cambiar contraseña", systemImage: "key") }
                    .accessibilityIdentifier("botonCambiarPassword")
            }

            if actual.rol.gestionaPisos {
                Section {
                    Button { hoja = .cobro } label: {
                        LabeledContent("Datos de cobro", value: actual.iban.map { "···· " + String($0.suffix(4)) } ?? "Sin IBAN")
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("botonDatosCobro")
                } footer: {
                    Text("IBAN para el QR de pago de tus inquilinos.")
                }

                Section("Mis estadísticas") {
                    if let r = resumen {
                        FilaMetrica(titulo: "Inquilinos", valor: "\(r.inquilinos)", icono: "person.2")
                        FilaMetrica(titulo: "Contratos activos", valor: "\(r.contratosActivos)", icono: "doc.text")
                        FilaMetrica(titulo: "Ocupación", valor: Formato.porcentaje(r.ocupacion.porcentaje),
                                    tono: r.ocupacion.tono, icono: "chart.pie")
                        FilaMetrica(titulo: "Cobrado este mes", valor: Formato.euros(r.cobradoMes), icono: "eurosign")
                        FilaMetrica(titulo: "Incidencias abiertas",
                                    valor: "\(r.incidenciasPendientes + r.incidenciasEnProceso)", icono: "wrench.and.screwdriver")
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }

                Section {
                    NavigationLink(value: DestinoPerfil.actividad) {
                        Label("Historial de actividad", systemImage: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("enlaceMiActividad")
                }
            }

            Section {
                Picker("Apariencia", selection: $apariencia) {
                    ForEach(Apariencia.allCases) { Text($0.nombre).tag($0) }
                }
                .accessibilityIdentifier("selectorApariencia")
            } footer: {
                Text("Automático sigue el modo claro u oscuro del iPhone.")
            }

            Section {
                Button("Cerrar sesión", role: .destructive) { confirmarSalida = true }
                    .frame(maxWidth: .infinity)
            }

            #if DEBUG
            Section("Desarrollo") {
                LabeledContent("Servidor", value: sesion.api.baseURL.absoluteString)
                    .font(Tema.Fuente.nota)
            }
            #endif
        }
        .navigationTitle("Perfil")
        .navigationDestination(for: DestinoPerfil.self) { _ in
            ActividadView(soloMia: true)
        }
        .sheet(item: $hoja) { hoja in
            NavigationStack {
                switch hoja {
                case .editar: EditarPerfilView(usuario: actual)
                case .password: CambiarPasswordView()
                case .cobro: DatosCobroView(usuario: actual)
                }
            }
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmarSalida, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { sesion.cerrarSesion() }
        }
        .task {
            guard actual.rol.gestionaPisos else { return }
            resumen = try? await sesion.api.enviar(.dashboard)
        }
    }
}

/// Nombre y email de la cuenta (PATCH /api/me).
struct EditarPerfilView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let usuario: Usuario

    @State private var nombre = ""
    @State private var email = ""
    @State private var guardando = false
    @State private var error: String?

    private var valido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@")
    }

    var body: some View {
        Form {
            Section {
                TextField("Nombre", text: $nombre)
                    .textContentType(.name)
                    .accessibilityIdentifier("campoNombre")
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("campoEmail")
            } footer: {
                Text("El email es el que usas para iniciar sesión.")
            }
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
            }
        }
        .navigationTitle("Editar perfil")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
            ToolbarItem(placement: .confirmationAction) {
                if guardando { ProgressView() } else {
                    Button("Guardar") { Task { await guardar() } }.disabled(!valido)
                }
            }
        }
        .onAppear {
            nombre = usuario.nombre
            email = usuario.email
        }
    }

    private func guardar() async {
        guardando = true
        defer { guardando = false }
        do {
            let req = ActualizarPerfilRequest(nombre: nombre.trimmingCharacters(in: .whitespaces),
                                              email: email.trimmingCharacters(in: .whitespaces))
            sesion.actualizar(usuario: try await sesion.api.enviar(.actualizarPerfil(req)))
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// PUT /api/me/password: pide la actual y la nueva dos veces.
struct CambiarPasswordView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar

    @State private var actual = ""
    @State private var nueva = ""
    @State private var repetida = ""
    @State private var guardando = false
    @State private var error: String?
    @State private var hecho = false

    /// Mensaje del primer problema del formulario, o nil si se puede enviar.
    var problema: String? { CambiarPasswordView.validar(actual: actual, nueva: nueva, repetida: repetida) }

    static func validar(actual: String, nueva: String, repetida: String) -> String? {
        if actual.isEmpty || nueva.isEmpty { return "" }
        if nueva.count < 8 { return "La nueva contraseña debe tener al menos 8 caracteres" }
        if nueva.count > 72 { return "La nueva contraseña es demasiado larga" }
        if nueva != repetida { return "Las contraseñas nuevas no coinciden" }
        return nil
    }

    var body: some View {
        Form {
            Section {
                SecureField("Contraseña actual", text: $actual)
                    .textContentType(.password)
                    .accessibilityIdentifier("campoPasswordActual")
            }
            Section {
                SecureField("Nueva contraseña", text: $nueva)
                    .textContentType(.newPassword)
                    .accessibilityIdentifier("campoPasswordNueva")
                SecureField("Repite la nueva", text: $repetida)
                    .textContentType(.newPassword)
                    .accessibilityIdentifier("campoPasswordRepetida")
            } footer: {
                if let p = problema, !p.isEmpty, !repetida.isEmpty {
                    Text(p).foregroundStyle(Tema.Color.aviso)
                } else {
                    Text("Mínimo 8 caracteres.")
                }
            }
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
            }
        }
        .navigationTitle("Cambiar contraseña")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
            ToolbarItem(placement: .confirmationAction) {
                if guardando { ProgressView() } else {
                    Button("Guardar") { Task { await guardar() } }.disabled(problema != nil)
                }
            }
        }
        .alert("Contraseña cambiada", isPresented: $hecho) {
            Button("Aceptar") { cerrar() }
        } message: {
            Text("La próxima vez que inicies sesión usa la nueva contraseña.")
        }
    }

    private func guardar() async {
        guardando = true
        defer { guardando = false }
        do {
            _ = try await sesion.api.enviar(.cambiarPassword(CambioPasswordRequest(actual: actual, nueva: nueva)))
            hecho = true
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
