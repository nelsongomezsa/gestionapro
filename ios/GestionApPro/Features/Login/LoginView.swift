import SwiftUI

struct LoginView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = LoginViewModel()
    @FocusState private var campo: Campo?

    private enum Campo { case email, password }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "building.2.crop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                        Text("GestionAp PRO")
                            .font(.title.bold())
                        Text("Gestión de alquiler de habitaciones")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                if let aviso = sesion.aviso {
                    Section {
                        Label(aviso, systemImage: "clock.badge.exclamationmark")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    TextField("Email", text: $vm.email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($campo, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { campo = .password }
                    SecureField("Contraseña", text: $vm.password)
                        .textContentType(.password)
                        .focused($campo, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await vm.entrar(con: sesion) } }
                }

                if let error = vm.error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await vm.entrar(con: sesion) }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.cargando { ProgressView() } else { Text("Iniciar sesión").bold() }
                            Spacer()
                        }
                    }
                    .disabled(!vm.puedeEnviar)
                }
            }
            .navigationTitle("Acceso")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
