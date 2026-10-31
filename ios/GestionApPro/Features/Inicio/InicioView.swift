import SwiftUI

/// Destinos que se abren desde Inicio (incluidos los de las notificaciones).
enum DestinoInicio: Hashable {
    case notificaciones
    case actividad
    case buscar
    case piso(Int)
    case inquilino(Int)
    case contrato(Int)
    case habitacion(Int)
    case incidencia(Int)
    case mensajes(Int)
    case mensajesIncidencia(Int)
}

/// Inicio (Dashboard del escritorio): lo cobrado del mes como cifra principal, indicadores,
/// ingresos de 6 meses, alertas, vencimientos, actividad, informe mensual en PDF,
/// búsqueda global y campana de notificaciones.
struct InicioView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = InicioViewModel()
    /// Ruta explícita: las notificaciones abren su pantalla añadiéndola aquí.
    @State private var ruta: [DestinoInicio] = []

    var body: some View {
        @Bindable var vm = vm
        NavigationStack(path: $ruta) {
            VistaCarga(estado: vm.estado, reintentar: { Task { await cargar() } }) { d in
                ScrollView {
                    VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                        HeroeInicio(dashboard: d, generandoInforme: vm.generandoInforme) {
                            Task { await vm.informe(con: sesion.api) }
                        }
                        IndicadoresInicio(dashboard: d)
                        SeccionTarjeta(titulo: "Ingresos cobrados") {
                            GraficoIngresos(meses: d.ingresosUltimos6Meses).frame(height: 220)
                        }
                        AlertasInicio(alertas: InicioViewModel.alertas(d))
                        VencimientosInicio(contratos: d.proximosVencimientos)
                        ActividadInicio(actividades: Array(d.actividadReciente.prefix(InicioViewModel.actividadesVisibles)))
                    }
                    .padding(.horizontal, Tema.Espacio.m)
                    .padding(.bottom, Tema.Espacio.l)
                }
                .background(Tema.Color.fondo)
            }
            .background(Tema.Color.fondo)
            .navigationTitle(InicioViewModel.saludo(nombre: sesion.usuario?.nombre))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: DestinoInicio.buscar) {
                        Label("Buscar", systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("botonBuscar")
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: DestinoInicio.notificaciones) {
                        Image(systemName: vm.noLeidas > 0 ? "bell.badge" : "bell")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Tema.Color.negativo, Tema.Color.texto)
                    }
                    .accessibilityLabel(vm.noLeidas > 0 ? "Notificaciones, \(vm.noLeidas) sin leer" : "Notificaciones")
                    .accessibilityIdentifier("campana")
                }
            }
            .navigationDestination(for: DestinoInicio.self) { destino in
                switch destino {
                case .notificaciones:
                    NotificacionesView(abrir: { ruta.append($0) }, alCambiar: { await vm.contarNoLeidas(con: sesion.api) })
                case .actividad: ActividadView()
                case .buscar: BuscarView()
                case let .piso(id): PisoDestinoView(id: id)
                case let .inquilino(id): InquilinoFichaView(id: id)
                case let .contrato(id): ContratoDetalleView(id: id)
                case let .mensajes(id): ChatView(hilo: .contrato(id))
                case let .mensajesIncidencia(id): ChatView(hilo: .incidencia(id))
                case let .habitacion(id): HabitacionDestinoView(id: id)
                case let .incidencia(id): IncidenciaDestinoView(id: id)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .datosCambiados)) { _ in Task { await cargar() } }
            .refreshable { await cargar() }
            .task { await cargar() }
            .visorPDF($vm.documento)
            .alertaError($vm.error)
        }
    }

    /// Carga y, si llegó el panel, actualiza el widget, los avisos locales y el registro del dispositivo.
    private func cargar() async {
        guard let d = await vm.cargar(con: sesion.api) else { return }
        await InicioViewModel.actualizarWidget(d, con: sesion.api)
        await AvisosLocales.programarPropietario(vencimientos: d.proximosVencimientos)
        await sesion.registrarDispositivo()
    }
}
