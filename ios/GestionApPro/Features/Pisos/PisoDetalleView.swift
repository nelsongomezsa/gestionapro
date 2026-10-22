import SwiftUI

struct PisoDetalleView: View {
    let piso: Piso

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SemaforoView(calificacion: piso.metricas?.calificacion)
                    VStack(alignment: .leading) {
                        Text((piso.metricas?.calificacion).texto)
                            .font(.headline)
                        Text(piso.ciudad.nombre)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let m = piso.metricas {
                Section("Rentabilidad") {
                    FilaDato(titulo: "Rentabilidad bruta", valor: Formato.porcentaje(m.rentabilidadBrutaPct))
                    FilaDato(titulo: "Rentabilidad neta", valor: Formato.porcentaje(m.rentabilidadNetaPct),
                             nota: "Antes de financiación")
                    FilaDato(titulo: "Cash-on-cash", valor: Formato.porcentaje(m.cashOnCashPct),
                             color: (m.cashOnCashPct ?? 0) < 0 ? .red : .primary,
                             nota: "Cash flow anual / capital propio")
                    FilaDato(titulo: "PER inmobiliario", valor: Formato.anios(m.perAnios))
                }
                Section("Flujo de caja") {
                    FilaDato(titulo: "Ingresos mensuales", valor: Formato.euros(piso.ingresosMensuales),
                             nota: "Contratos activos hoy")
                    FilaDato(titulo: "Cuota hipoteca", valor: Formato.euros(m.cuotaMensualHipoteca))
                    FilaDato(titulo: "Gastos anuales", valor: Formato.euros(m.gastosAnuales))
                    FilaDato(titulo: "Cash flow mensual", valor: Formato.euros(m.cashFlowMensual),
                             color: m.cashFlowMensual.colorSigno)
                }
                Section("Inversión") {
                    FilaDato(titulo: "Inversión total", valor: Formato.euros(m.inversionTotal))
                    FilaDato(titulo: "Capital propio", valor: Formato.euros(m.capitalPropio))
                    FilaDato(titulo: "Plusvalía latente", valor: Formato.euros(m.plusvaliaLatente),
                             color: m.plusvaliaLatente.colorSigno)
                }
            } else {
                Section {
                    ContentUnavailableView("Sin datos financieros", systemImage: "chart.bar.xaxis",
                                           description: Text("Añade los datos de compra y gastos para ver las métricas."))
                }
            }

            Section("Ocupación") {
                FilaDato(titulo: "Habitaciones", valor: "\(piso.ocupacion.total)")
                FilaDato(titulo: "Alquiladas", valor: "\(piso.ocupacion.alquiladas)")
                FilaDato(titulo: "Disponibles", valor: "\(piso.ocupacion.disponibles)")
                FilaDato(titulo: "En mantenimiento", valor: "\(piso.ocupacion.mantenimiento)")
            }

            if let notas = piso.datosFinancieros?.notas, !notas.isEmpty {
                Section("Notas") {
                    Text(notas).font(.callout)
                }
            }
        }
        .navigationTitle(piso.direccion)
        .navigationBarTitleDisplayMode(.inline)
    }
}
