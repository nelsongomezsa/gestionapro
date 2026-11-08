import SwiftUI

/// "Por piso" o "Todos": cómo se ve una lista (Cobros, Inquilinos, Contratos, Incidencias).
/// Cada pantalla recuerda su elección con `@AppStorage(Agrupacion.clave("…"))`.
enum Agrupacion: String, CaseIterable, Identifiable, Sendable {
    case porPiso, todos

    var id: Self { self }

    var nombre: LocalizedStringKey {
        switch self {
        case .porPiso: "Por inmueble"
        case .todos: "Todos"
        }
    }

    static func clave(_ pantalla: String) -> String { "agrupacion.\(pantalla)" }
}

/// Elementos de un piso (o sin piso, al final).
struct GrupoPiso<Elemento: Identifiable>: Identifiable {
    let piso: PisoBreve?
    let elementos: [Elemento]
    /// -1 para el grupo sin piso.
    var id: Int { piso?.id ?? -1 }
}

enum AgrupadorPiso {
    /// Agrupa conservando el orden de cada lista; pisos por dirección y "sin piso" al final.
    static func agrupar<E: Identifiable>(_ elementos: [E], piso: (E) -> PisoBreve?) -> [GrupoPiso<E>] {
        var orden: [Int] = []
        var pisos: [Int: PisoBreve] = [:]
        var porPiso: [Int: [E]] = [:]
        for e in elementos {
            let p = piso(e)
            let id = p?.id ?? -1
            if porPiso[id] == nil { orden.append(id) }
            porPiso[id, default: []].append(e)
            if let p { pisos[id] = p }
        }
        return orden
            .map { GrupoPiso(piso: pisos[$0], elementos: porPiso[$0] ?? []) }
            .sorted { a, b in
                guard let pa = a.piso else { return false }
                guard let pb = b.piso else { return true }
                return pa.direccion.localizedStandardCompare(pb.direccion) == .orderedAscending
            }
    }
}

/// Selector "Por piso / Todos" para la cabecera de una lista.
struct SelectorAgrupacion: View {
    @Binding var agrupacion: Agrupacion

    var body: some View {
        Picker("Agrupar", selection: $agrupacion.animation(Tema.Movimiento.suave)) {
            ForEach(Agrupacion.allCases) { Text($0.nombre).tag($0) }
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: agrupacion)
        .accessibilityIdentifier("selectorAgrupacion")
    }
}

/// Un bloque plegable por piso dentro de una `List`, con su resumen en la cabecera.
/// Qué pisos están plegados se recuerda por pantalla.
struct SeccionesPorPiso<Elemento: Identifiable, Fila: View>: View {
    let grupos: [GrupoPiso<Elemento>]
    /// Resumen de cada piso ("3 contratos · 1.350 €/mes").
    let resumen: (GrupoPiso<Elemento>) -> String
    /// Título del grupo sin piso ("Sin contrato activo").
    var sinPiso: String = "Sin inmueble"
    @ViewBuilder let fila: (Elemento) -> Fila

    @AppStorage private var plegadosTexto: String

    init(grupos: [GrupoPiso<Elemento>], pantalla: String, sinPiso: String = "Sin inmueble",
         resumen: @escaping (GrupoPiso<Elemento>) -> String, @ViewBuilder fila: @escaping (Elemento) -> Fila) {
        self.grupos = grupos
        self.resumen = resumen
        self.sinPiso = sinPiso
        self.fila = fila
        _plegadosTexto = AppStorage(wrappedValue: "", "plegados.\(pantalla)")
    }

    private var plegados: Set<Int> { Set(plegadosTexto.split(separator: ",").compactMap { Int($0) }) }

    var body: some View {
        ForEach(grupos) { g in
            let plegado = plegados.contains(g.id)
            Section {
                if !plegado { ForEach(g.elementos) { fila($0) } }
            } header: {
                CabeceraPiso(titulo: g.piso?.direccion ?? String(localized: String.LocalizationValue(sinPiso)),
                             subtitulo: g.piso?.ciudad, resumen: resumen(g), cantidad: g.elementos.count,
                             plegado: plegado) { alternar(g.id) }
            }
            .filaLista()
        }
    }

    private func alternar(_ id: Int) {
        var p = plegados
        if p.contains(id) { p.remove(id) } else { p.insert(id) }
        withAnimation(Tema.Movimiento.suave) { plegadosTexto = p.sorted().map(String.init).joined(separator: ",") }
    }
}

/// Cabecera tocable de un bloque de piso: dirección, resumen, número de elementos y chevron.
private struct CabeceraPiso: View {
    let titulo: String
    let subtitulo: String?
    let resumen: String
    let cantidad: Int
    let plegado: Bool
    let alternar: () -> Void

    var body: some View {
        Button {
            Haptica.ligera()
            alternar()
        } label: {
            HStack(alignment: .center, spacing: Tema.Espacio.s) {
                VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                    Text(titulo).font(Tema.Fuente.subtitulo).foregroundStyle(Tema.Color.texto)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(resumen).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Tema.Espacio.xs)
                Text("\(cantidad)")
                    .font(Tema.Fuente.nota.weight(.semibold)).monospacedDigit()
                    .padding(.horizontal, Tema.Espacio.xs).padding(.vertical, Tema.Espacio.linea)
                    .background(Tema.Color.superficieElevada, in: .capsule)
                    .foregroundStyle(Tema.Color.texto)
                Image(systemName: "chevron.down")
                    .font(Tema.Fuente.nota.weight(.semibold))
                    .foregroundStyle(Tema.Color.textoSecundario)
                    .rotationEffect(.degrees(plegado ? -90 : 0))
            }
            .padding(.vertical, Tema.Espacio.xxs)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titulo). \(resumen)")
        .accessibilityValue(plegado ? Text("Plegado") : Text("Desplegado"))
        .accessibilityHint(plegado ? Text("Toca dos veces para ver sus \(cantidad) elementos") : Text("Toca dos veces para plegarlo"))
        .accessibilityAddTraits([.isButton, .isHeader])
        .accessibilityIdentifier("cabeceraPiso")
    }
}
