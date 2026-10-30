import Charts
import SwiftUI

/// Estadísticas (EstadisticasController del escritorio), filtradas por propietario.
struct EstadisticasView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<Estadisticas> = .cargando

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { e in
            ScrollView {
                VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                    heroe(e)

                    SeccionTarjeta(titulo: "Ingresos cobrados · 12 meses") {
                        GraficoIngresos(meses: e.ingresos12Meses).frame(height: 220)
                    }

                    SeccionTarjeta(titulo: "Habitaciones por estado") {
                        AnilloHabitaciones(ocupacion: e.ocupacion)
                    }

                    SeccionTarjeta(titulo: "Incidencias comunicadas · 6 meses") {
                        Chart(e.incidencias6Meses, id: \.mes) { m in
                            BarMark(x: .value("Mes", m.etiqueta), y: .value("Incidencias", m.cantidad), width: .ratio(0.55))
                                .foregroundStyle(Tema.Color.aviso)
                                .clipShape(.rect(cornerRadius: Tema.Radio.pequeno / 2))
                                .annotation(position: .top) {
                                    if m.cantidad > 0 {
                                        Text("\(m.cantidad)").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                                    }
                                }
                                .accessibilityLabel(m.etiqueta.capitalized(with: Formato.locale))
                                .accessibilityValue("\(m.cantidad) incidencias")
                        }
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisValueLabel().font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                            }
                        }
                        .frame(height: 160)
                        .accessibilityLabel("Incidencias por mes")
                    }
                }
                .padding(.horizontal, Tema.Espacio.m)
                .padding(.bottom, Tema.Espacio.l)
            }
            .background(Tema.Color.fondo)
        }
        .background(Tema.Color.fondo)
        .navigationTitle("Estadísticas")
        .refreshable { await cargar() }
        .task { await cargar() }
    }

    /// Lo cobrado este año; la variación es frente al año pasado hasta la misma fecha.
    private func heroe(_ e: Estadisticas) -> some View {
        let fecha = e.fechaComparada.formatted(.dateTime.day().month(.abbreviated).locale(Formato.locale))
        return TarjetaHero(titulo: "Cobrado en \(String(e.anioActual)) hasta hoy", valor: Formato.euros(e.ingresosAnioActual),
                           accesorio: e.variacionAnualPct.map { v in
                               AnyView(InsigniaEstado(texto: "\(Formato.porcentaje(abs(v))) vs. \(String(e.anioActual - 1))",
                                                      tono: Tono.signo(v), icono: v >= 0 ? "arrow.up.right" : "arrow.down.right")
                                   .accessibilityLabel("\(v >= 0 ? "Sube" : "Baja") un \(Formato.porcentaje(abs(v))) frente a \(String(e.anioActual - 1)) hasta el \(fecha)"))
                           }) {
            ParDatos {
                DatoCompacto(titulo: "\(String(e.anioActual - 1)) hasta el \(fecha)", valor: Formato.euros(e.ingresosAnioAnteriorHastaHoy))
            } derecha: {
                // Si todo lo del año pasado se cobró antes de esta fecha, la cifra sería la misma.
                if e.ingresosAnioAnterior != e.ingresosAnioAnteriorHastaHoy {
                    DatoCompacto(titulo: "\(String(e.anioActual - 1)) completo", valor: Formato.euros(e.ingresosAnioAnterior))
                }
            }
        }
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(.estadisticas)) }
        catch .noAutorizado {}
        catch { estado = .error(error.localizedDescription) }
    }
}

/// Anillo con las habitaciones alquiladas, disponibles y en mantenimiento, y su leyenda.
struct AnilloHabitaciones: View {
    let ocupacion: Ocupacion

    private var porciones: [(nombre: String, cantidad: Int, tono: Tono)] {
        [("Alquiladas", ocupacion.alquiladas, .positivo),
         ("Disponibles", ocupacion.disponibles, .primario),
         ("En mantenimiento", ocupacion.mantenimiento, .aviso)]
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tema.Espacio.l) { anillo; leyenda }
            VStack(spacing: Tema.Espacio.m) { anillo; leyenda }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Habitaciones: \(Formato.porcentaje(ocupacion.porcentaje)) de ocupación")
        .accessibilityValue(porciones.map { "\($0.cantidad) \($0.nombre.lowercased())" }.joined(separator: ", "))
    }

    private var anillo: some View {
        Chart(porciones, id: \.nombre) { p in
            SectorMark(angle: .value("Habitaciones", p.cantidad), innerRadius: .ratio(0.65), angularInset: 1.5)
                .foregroundStyle(p.tono.color)
                .cornerRadius(Tema.Radio.pequeno / 2)
        }
        .frame(width: Tema.Tamano.anillo, height: Tema.Tamano.anillo)
        .overlay {
            VStack(spacing: 0) {
                Text(Formato.porcentaje(ocupacion.porcentaje)).font(Tema.Fuente.cifraPequena).foregroundStyle(Tema.Color.texto)
                Text("ocupación").font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
            }
        }
    }

    private var leyenda: some View {
        VStack(alignment: .leading, spacing: Tema.Espacio.s) {
            ForEach(porciones, id: \.nombre) { p in
                HStack(spacing: Tema.Espacio.xs) {
                    Circle().fill(p.tono.color).frame(width: Tema.Tamano.punto * 1.5, height: Tema.Tamano.punto * 1.5)
                    Text(p.nombre).font(Tema.Fuente.detalle).foregroundStyle(Tema.Color.texto)
                    Spacer(minLength: Tema.Espacio.xs)
                    Text("\(p.cantidad)").font(Tema.Fuente.cifraPequena).foregroundStyle(Tema.Color.texto)
                }
            }
            Text("de \(ocupacion.habitaciones) habitaciones")
                .font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
        }
    }
}
