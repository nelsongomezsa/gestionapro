import SwiftUI

/// Inicio. En la fase 4A muestra el resumen de la cartera; el dashboard completo
/// (gráficos, alertas, vencimientos, actividad, notificaciones) llega en la 4D.
struct InicioView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var vm = PisosViewModel()

    private let columnas = [GridItem(.flexible(), spacing: Tema.Espacio.s), GridItem(.flexible(), spacing: Tema.Espacio.s)]

    var body: some View {
        NavigationStack {
            VistaCarga(estado: vm.estado, reintentar: { Task { await vm.cargar(con: sesion.api) } }) { _ in
                ScrollView {
                    VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                        ResumenCarteraView(resumen: vm.resumen)
                        LazyVGrid(columns: columnas, spacing: Tema.Espacio.s) {
                            let r = vm.resumen
                            TarjetaKPI(titulo: "Ingresos del mes", valor: Formato.euros(r.ingresosMensuales), icono: "eurosign")
                            TarjetaKPI(titulo: "Cash flow total", valor: Formato.euros(r.cashFlowMensual),
                                       icono: "arrow.left.arrow.right", tono: Tono.signo(r.cashFlowMensual))
                            TarjetaKPI(titulo: "Ocupación", valor: Formato.porcentaje(r.ocupacion * 100), icono: "chart.pie",
                                       tono: r.ocupacion >= 0.75 ? .positivo : (r.ocupacion >= 0.5 ? .aviso : .negativo),
                                       detalle: "\(r.alquiladas) de \(r.habitaciones) habitaciones")
                            TarjetaKPI(titulo: "Habitaciones libres", valor: "\(r.disponibles)", icono: "door.left.hand.open",
                                       tono: .neutro)
                        }
                    }
                    .padding(Tema.Espacio.m)
                }
                .background(Tema.Color.fondo)
            }
            .navigationTitle(saludo)
            .refreshable { await vm.cargar(con: sesion.api) }
            .task { await vm.cargar(con: sesion.api) }
        }
    }

    private var saludo: String {
        let nombre = sesion.usuario?.nombre.split(separator: " ").first.map(String.init) ?? ""
        return nombre.isEmpty ? "Inicio" : "Hola, \(nombre)"
    }
}
