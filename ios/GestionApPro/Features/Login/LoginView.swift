import SwiftUI

struct LoginView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = LoginViewModel()
    @FocusState private var campo: Campo?

    private enum Campo { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: Tema.Espacio.xl) {
                VStack(spacing: Tema.Espacio.s) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .background(Tema.Color.degradadoMarca, in: .rect(cornerRadius: 24))
                        .accessibilityHidden(true)
                    Text("GestionAp PRO")
                        .font(.largeTitle.bold())
                    Text("Gestión de alquiler de habitaciones")
                        .foregroundStyle(Tema.Color.textoSecundario)
                }
                .padding(.top, Tema.Espacio.xxl)

                if let aviso = sesion.aviso {
                    Label(aviso, systemImage: "clock.badge.exclamationmark")
                        .font(Tema.Fuente.detalle)
                        .foregroundStyle(Tema.Color.aviso)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tarjeta(relleno: Tema.Espacio.s)
                }

                VStack(spacing: 0) {
                    TextField("Email", text: $vm.email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($campo, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { campo = .password }
                        .padding(Tema.Espacio.m)
                    Divider().padding(.leading, Tema.Espacio.m)
                    SecureField("Contraseña", text: $vm.password)
                        .textContentType(.password)
                        .focused($campo, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await vm.entrar(con: sesion) } }
                        .padding(Tema.Espacio.m)
                }
                .background(Tema.Color.superficie, in: .rect(cornerRadius: Tema.Radio.grande))
                .overlay(RoundedRectangle(cornerRadius: Tema.Radio.grande).strokeBorder(Tema.Color.borde, lineWidth: 0.5))

                if let error = vm.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(Tema.Fuente.detalle)
                        .foregroundStyle(Tema.Color.negativo)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                BotonPrincipal(titulo: "Iniciar sesión", cargando: vm.cargando) {
                    Task { await vm.entrar(con: sesion) }
                }
                .disabled(!vm.puedeEnviar)
            }
            .padding(Tema.Espacio.l)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Tema.Color.fondo)
        .scrollDismissesKeyboard(.interactively)
    }
}
