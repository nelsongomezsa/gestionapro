import SwiftUI

/// Gestión de usuarios (solo admin), como el panel de usuarios del escritorio:
/// lista, alta, activar o desactivar y cambiar el rol.
struct UsuariosView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<[UsuarioAdmin]> = .cargando
    @State private var creando = false
    @State private var error: String?

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { lista in
            List {
                Section {
                    ForEach(lista) { u in
                        FilaUsuario(usuario: u, esYo: u.id == sesion.usuario?.id)
                            .contextMenu { if u.id != sesion.usuario?.id { acciones(de: u) } }
                            .swipeActions(edge: .trailing) {
                                if u.id != sesion.usuario?.id {
                                    Button(u.activo ? "Desactivar" : "Activar") {
                                        Task { await enviar(.cambiarActivo(usuario: u.id, activo: !u.activo)) }
                                    }
                                    .tint(u.activo ? Tema.Color.negativoRelleno : Tema.Color.positivo)
                                }
                            }
                    }
                }
                .filaLista()
            }
            .estiloLista()
            .overlay { if lista.isEmpty { EstadoVacio(icono: "person.2", titulo: "Sin usuarios") } }
            .refreshable { await cargar() }
        }
        .navigationTitle("Usuarios")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { creando = true } label: { Label("Nuevo usuario", systemImage: "plus") }
                    .accessibilityIdentifier("botonNuevoUsuario")
            }
        }
        .sheet(isPresented: $creando) {
            NavigationStack { NuevoUsuarioView { Task { await cargar() } } }
        }
        .alertaError($error)
        .task { await cargar() }
    }

    /// Mismas reglas que la API: un inquilino no cambia de rol y nadie pasa a ser inquilino.
    @ViewBuilder
    private func acciones(de u: UsuarioAdmin) -> some View {
        if u.rol != .inquilino {
            let otro: Rol = u.rol == .admin ? .propietario : .admin
            Button("Hacer \(otro.nombreVisible.lowercased())", systemImage: "person.badge.shield.checkmark") {
                Task { await enviar(.cambiarRol(usuario: u.id, a: otro)) }
            }
        }
        Button(u.activo ? "Desactivar" : "Activar", systemImage: u.activo ? "person.slash" : "person.badge.plus",
               role: u.activo ? .destructive : nil) {
            Task { await enviar(.cambiarActivo(usuario: u.id, activo: !u.activo)) }
        }
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(.usuarios)) }
        catch .noAutorizado {}
        catch { estado = .error(error.localizedDescription) }
    }

    private func enviar(_ endpoint: Endpoint<UsuarioAdmin>) async {
        do {
            let cambiado = try await sesion.api.enviar(endpoint)
            if case var .cargado(lista) = estado, let i = lista.firstIndex(where: { $0.id == cambiado.id }) {
                lista[i] = cambiado
                estado = .cargado(lista)
            }
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct FilaUsuario: View {
    let usuario: UsuarioAdmin
    let esYo: Bool

    var body: some View {
        // Rol y estado bajo el email: así el email tiene todo el ancho y no se parte.
        HStack(alignment: .top, spacing: Tema.Espacio.s) {
            AvatarIniciales(nombre: usuario.nombre, tamano: Tema.Tamano.avatarFila)
                .opacity(usuario.activo ? 1 : 0.4)
            VStack(alignment: .leading, spacing: Tema.Espacio.xxs) {
                Text(esYo ? "\(usuario.nombre) (tú)" : usuario.nombre).font(Tema.Fuente.subtitulo)
                Text(usuario.email).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tema.Espacio.xxs) { insignias }
                    VStack(alignment: .leading, spacing: Tema.Espacio.xxs) { insignias }
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var insignias: some View {
        InsigniaEstado(texto: usuario.rol.nombreVisible, tono: usuario.rol == .admin ? .primario : .neutro)
        if !usuario.activo { InsigniaEstado(texto: "Inactivo", tono: .negativo) }
    }
}

/// Alta de un administrador o propietario (los inquilinos entran con su invitación).
struct NuevoUsuarioView: View {
    @Environment(SesionStore.self) private var sesion
    @Environment(\.dismiss) private var cerrar
    let alCrear: () -> Void

    @State private var nombre = ""
    @State private var email = ""
    @State private var password = ""
    @State private var rol: Rol = .propietario
    @State private var guardando = false
    @State private var error: String?

    private var valido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@") && (8...72).contains(password.count)
    }

    var body: some View {
        Form {
            Section {
                TextField("Nombre", text: $nombre).textContentType(.name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Contraseña inicial", text: $password).textContentType(.newPassword)
            } footer: {
                Text("Mínimo 8 caracteres. Pásasela a la persona para que la cambie desde su perfil.")
            }
            .filaLista()
            Section {
                Picker("Rol", selection: $rol) {
                    Text(Rol.propietario.nombreVisible).tag(Rol.propietario)
                    Text(Rol.admin.nombreVisible).tag(Rol.admin)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Los inquilinos crean su cuenta con el código de invitación de su ficha.")
            }
            .filaLista()
            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tema.Color.negativo) }
                .filaLista()
            }
        }
        .estiloLista()
        .navigationTitle("Nuevo usuario")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
            ToolbarItem(placement: .confirmationAction) {
                if guardando { ProgressView() } else {
                    Button("Crear") { Task { await crear() } }.disabled(!valido)
                }
            }
        }
    }

    private func crear() async {
        guardando = true
        defer { guardando = false }
        do {
            _ = try await sesion.api.enviar(.crearUsuario(NuevoUsuarioRequest(
                nombre: nombre.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces),
                password: password, rol: rol)))
            alCrear()
            cerrar()
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
