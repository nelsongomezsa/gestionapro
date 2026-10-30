import SwiftUI

struct LoginView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = LoginViewModel()
    @FocusState private var campo: Campo?
    @State private var registrando = false

    private enum Campo { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: Tema.Espacio.l) {
                VStack(spacing: Tema.Espacio.s) {
                    Image("Marca")
                        .resizable()
                        .frame(width: Tema.Tamano.logo, height: Tema.Tamano.logo)
                        .clipShape(.rect(cornerRadius: Tema.Radio.tarjeta, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Tema.Radio.tarjeta, style: .continuous)
                            .strokeBorder(Tema.Color.bordeHeroe))
                        .accessibilityHidden(true)
                    Text("GestionAp PRO")
                        .font(Tema.Fuente.tituloMarca)
                    Text("Gestión de alquiler de habitaciones")
                        .foregroundStyle(Tema.Color.textoSecundario)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Tema.Espacio.xl)

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
                .overlay(RoundedRectangle(cornerRadius: Tema.Radio.grande).strokeBorder(Tema.Color.borde))

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

                Button("Soy inquilino y tengo un código") { registrando = true }
                    .font(Tema.Fuente.detalle)
                    .accessibilityIdentifier("botonTengoCodigo")
            }
            .padding(Tema.Espacio.l)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Tema.Color.fondo)
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $registrando) {
            NavigationStack { RegistroInquilinoView() }
        }
    }
}
