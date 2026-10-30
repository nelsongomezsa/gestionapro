import SwiftUI

struct PisoDetalleView: View {
    let piso: Piso

    private let columnas = [GridItem(.flexible(), spacing: Tema.Espacio.s), GridItem(.flexible(), spacing: Tema.Espacio.s)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                cabecera

                if let m = piso.metricas {
                    LazyVGrid(columns: columnas, spacing: Tema.Espacio.s) {
                        TarjetaKPI(titulo: "Cash flow mensual", valor: Formato.euros(m.cashFlowMensual),
                                   icono: "arrow.left.arrow.right", tono: Tono.signo(m.cashFlowMensual))
                        TarjetaKPI(titulo: "Rentabilidad bruta", valor: Formato.porcentaje(m.rentabilidadBrutaPct),
                                   icono: "percent", tono: (m.calificacion as Calificacion?).tono)
                        TarjetaKPI(titulo: "Rentabilidad neta", valor: Formato.porcentaje(m.rentabilidadNetaPct),
                                   icono: "chart.line.uptrend.xyaxis", tono: Tono.signo(m.rentabilidadNetaPct),
                                   detalle: "Antes de financiación")
                        TarjetaKPI(titulo: "Cash-on-cash", valor: Formato.porcentaje(m.cashOnCashPct),
                                   icono: "banknote", tono: Tono.signo(m.cashOnCashPct),
                                   detalle: "Cash flow anual / capital propio")
                    }

                    seccion("Flujo de caja") {
                        FilaMetrica(titulo: "Ingresos mensuales", valor: Formato.euros(piso.ingresosMensuales),
                                    nota: "Contratos activos hoy")
                        Divider()
                        FilaMetrica(titulo: "Cuota de hipoteca", valor: Formato.euros(m.cuotaMensualHipoteca))
                        Divider()
                        FilaMetrica(titulo: "Gastos anuales", valor: Formato.euros(m.gastosAnuales))
                        Divider()
                        FilaMetrica(titulo: "Cash flow mensual", valor: Formato.euros(m.cashFlowMensual),
                                    tono: Tono.signo(m.cashFlowMensual))
                    }

                    seccion("Inversión") {
                        FilaMetrica(titulo: "Inversión total", valor: Formato.euros(m.inversionTotal))
                        Divider()
                        FilaMetrica(titulo: "Capital propio", valor: Formato.euros(m.capitalPropio))
                        Divider()
                        FilaMetrica(titulo: "Plusvalía latente", valor: Formato.euros(m.plusvaliaLatente),
                                    tono: Tono.signo(m.plusvaliaLatente))
                        Divider()
                        FilaMetrica(titulo: "PER inmobiliario", valor: Formato.anios(m.perAnios),
                                    nota: "Años de alquiler para pagar la inversión")
                    }
                } else {
                    EstadoVacio(icono: "chart.bar.xaxis", titulo: "Sin datos financieros",
                                mensaje: "Añade los datos de compra y gastos para ver las métricas.")
                        .tarjeta()
                }

                seccion("Ocupación") {
                    FilaMetrica(titulo: "Habitaciones", valor: "\(piso.ocupacion.total)", icono: "bed.double")
                    Divider()
                    FilaMetrica(titulo: "Alquiladas", valor: "\(piso.ocupacion.alquiladas)", tono: .positivo, icono: "key")
                    Divider()
                    FilaMetrica(titulo: "Disponibles", valor: "\(piso.ocupacion.disponibles)", icono: "door.left.hand.open")
                    Divider()
                    FilaMetrica(titulo: "En mantenimiento", valor: "\(piso.ocupacion.mantenimiento)",
                                tono: piso.ocupacion.mantenimiento > 0 ? .aviso : nil, icono: "wrench")
                }

                if let notas = piso.datosFinancieros?.notas, !notas.isEmpty {
                    seccion("Notas") {
                        Text(notas).font(Tema.Fuente.detalle)
                    }
                }
            }
            .padding(Tema.Espacio.m)
        }
        .background(Tema.Color.fondo)
        .navigationTitle("Piso")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            (piso.metricas?.calificacion).insignia
            Text(piso.direccion)
                .font(Tema.Fuente.titulo)
                .fixedSize(horizontal: false, vertical: true)
            Label(piso.ciudad.nombre, systemImage: "mappin.and.ellipse")
                .foregroundStyle(Tema.Color.textoSecundario)
        }
    }

    private func seccion<Contenido: View>(_ titulo: String, @ViewBuilder contenido: () -> Contenido) -> some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            Text(titulo).estiloEtiqueta().padding(.horizontal, Tema.Espacio.xxs)
            VStack(alignment: .leading, spacing: Tema.Espacio.s) { contenido() }
                .tarjeta()
        }
    }
}
