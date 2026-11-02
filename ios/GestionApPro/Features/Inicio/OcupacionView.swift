import SwiftUI

/// Ocupación (tarjeta de Inicio): el % total y cada piso con su barra, de menor a mayor ocupación.
struct OcupacionView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var estado: EstadoCarga<[Piso]> = .cargando
    /// Abre una pantalla en la pila de Inicio.
    let abrir: (DestinoInicio) -> Void

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { pisos in
            ScrollView {
                VStack(alignment: .leading, spacing: Tema.Espacio.l) {
                    let total = ResumenesInicio.total(pisos)
                    TarjetaHero(titulo: "Ocupación total",
                                valor: Formato.porcentaje(ResumenesInicio.porcentaje(total))) {
                        BarraOcupacion(ocupacion: total)
                        LeyendaOcupacion(ocupacion: total)
                    }
                    .aparicion(0)

                    if pisos.isEmpty {
                        EstadoVacio(icono: "building.2", titulo: "Sin pisos", mensaje: "Añade un piso para ver su ocupación.")
                    } else {
                        SeccionTarjeta(titulo: "Por piso · de menor a mayor") {
                            let ordenados = ResumenesInicio.porOcupacion(pisos)
                            ForEach(ordenados) { p in
                                TarjetaTocable(pista: "Abre el detalle del piso", mostrarChevron: false,
                                               accion: { abrir(.piso(p.id)) }) { FilaOcupacionPiso(piso: p) }
                                if p.id != ordenados.last?.id { Divider().overlay(Tema.Color.borde) }
                            }
                        }
                        .aparicion(1)
                    }
                }
                .padding(.horizontal, Tema.Espacio.m)
                .padding(.bottom, Tema.Espacio.l)
            }
            .background(Tema.Color.fondo)
        }
        .background(Tema.Color.fondo)
        .navigationTitle("Ocupación")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await cargar() }
        .task { await cargar() }
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(.pisos)) }
        catch .noAutorizado {}
        catch {
            if estado.valor == nil { estado = .error(error.localizedDescription) }
        }
    }
}

private struct FilaOcupacionPiso: View {
    let piso: Piso

    var body: some View {
        let o = piso.ocupacion
        let pct = ResumenesInicio.porcentaje(o)
        VStack(alignment: .leading, spacing: Tema.Espacio.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Tema.Espacio.s) {
                VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                    Text(piso.direccion).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(piso.ciudad.nombre).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                }
                Spacer(minLength: Tema.Espacio.xs)
                Text(Formato.porcentaje(pct)).font(Tema.Fuente.cifraPequena).foregroundStyle(Tono.ocupacion(pct).color)
                ChevronTocable()
            }
            BarraOcupacion(ocupacion: o)
            Text(ocupacionTexto(o)).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
        }
        .padding(.vertical, Tema.Espacio.xxs)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(piso.direccion), \(Formato.porcentaje(pct)) de ocupación. \(ocupacionTexto(o))")
    }
}

/// "3 ocupadas · 1 libre · 1 en mantenimiento"
func ocupacionTexto(_ o: Piso.Ocupacion) -> String {
    var partes = [o.alquiladas == 1 ? "1 ocupada" : "\(o.alquiladas) ocupadas",
                  o.disponibles == 1 ? "1 libre" : "\(o.disponibles) libres"]
    if o.mantenimiento > 0 { partes.append("\(o.mantenimiento) en mantenimiento") }
    return partes.joined(separator: " · ")
}

/// Barra apilada: ocupadas, libres y en mantenimiento (los colores de cada estado de habitación).
struct BarraOcupacion: View {
    let ocupacion: Piso.Ocupacion

    var body: some View {
        let o = ocupacion
        let tramos: [(Int, Tono)] = [(o.alquiladas, EstadoHabitacion.alquilada.tono),
                                     (o.disponibles, EstadoHabitacion.disponible.tono),
                                     (o.mantenimiento, EstadoHabitacion.mantenimiento.tono)]
        GeometryReader { geo in
            HStack(spacing: 2) {
                if o.total == 0 {
                    Capsule().fill(Tema.Color.superficieElevada)
                } else {
                    ForEach(Array(tramos.enumerated()), id: \.offset) { _, t in
                        if t.0 > 0 {
                            Capsule().fill(t.1.color)
                                .frame(width: max((geo.size.width - 4) * CGFloat(t.0) / CGFloat(o.total), 4))
                        }
                    }
                }
            }
        }
        .frame(height: Tema.Tamano.alturaBarraProgreso + 2)
        .accessibilityHidden(true)
    }
}

/// Leyenda de la barra de ocupación.
struct LeyendaOcupacion: View {
    let ocupacion: Piso.Ocupacion

    var body: some View {
        ViewThatFits {
            HStack(spacing: Tema.Espacio.m) { elementos }
            VStack(alignment: .leading, spacing: Tema.Espacio.xxs) { elementos }
        }
        .font(Tema.Fuente.nota)
        .foregroundStyle(Tema.Color.textoSecundario)
    }

    @ViewBuilder private var elementos: some View {
        punto("\(ocupacion.alquiladas) ocupadas", EstadoHabitacion.alquilada.tono)
        punto("\(ocupacion.disponibles) libres", EstadoHabitacion.disponible.tono)
        punto("\(ocupacion.mantenimiento) en mantenimiento", EstadoHabitacion.mantenimiento.tono)
    }

    private func punto(_ texto: String, _ tono: Tono) -> some View {
        HStack(spacing: Tema.Espacio.xxs) {
            Circle().fill(tono.color).frame(width: Tema.Tamano.punto * 1.5, height: Tema.Tamano.punto * 1.5)
            Text(texto)
        }
        .accessibilityElement(children: .combine)
    }
}
