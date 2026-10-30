import SwiftUI

/// Búsqueda global (la caja de la barra superior del escritorio): pisos, inquilinos,
/// contratos e incidencias. Sin distinguir tildes ni mayúsculas.
struct BuscarView: View {
    @Environment(SesionStore.self) private var sesion
    @State private var texto = ""
    @State private var resultados: ResultadosBusqueda?
    @State private var buscando = false
    @State private var error: String?

    private var consulta: String { texto.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        List {
            if let r = resultados, consulta.count >= 2 {
                grupo("Pisos", icono: "building.2", r.pisos) { DestinoInicio.piso($0) }
                grupo("Inquilinos", icono: "person", r.inquilinos) { DestinoInicio.inquilino($0) }
                grupo("Contratos", icono: "doc.text", r.contratos) { DestinoInicio.contrato($0) }
                grupo("Incidencias", icono: "wrench.and.screwdriver", r.incidencias) { DestinoInicio.incidencia($0) }
            }
        }
        .estiloLista()
        .overlay {
            if consulta.count < 2 {
                EstadoVacio(icono: "magnifyingglass", titulo: "Buscar",
                            mensaje: "Escribe al menos 2 letras: dirección, nombre, DNI, teléfono o incidencia.")
            } else if let error {
                EstadoVacio(icono: "exclamationmark.triangle", titulo: "No se pudo buscar", mensaje: error)
            } else if resultados?.vacio == true, !buscando {
                ContentUnavailableView.search(text: consulta)
            }
        }
        .navigationTitle("Buscar")
        .searchable(text: $texto, placement: .navigationBarDrawer(displayMode: .always), prompt: "Pisos, inquilinos, contratos…")
        .autocorrectionDisabled()
        .task(id: consulta) { await buscar() }
    }

    @ViewBuilder
    private func grupo(_ titulo: String, icono: String, _ lista: [ResultadosBusqueda.Resultado],
                       destino: @escaping (Int) -> DestinoInicio) -> some View {
        if !lista.isEmpty {
            Section(titulo) {
                ForEach(lista, id: \.self) { r in
                    NavigationLink(value: destino(r.id)) {
                        Label {
                            VStack(alignment: .leading, spacing: Tema.Espacio.linea) {
                                Text(r.titulo)
                                if let s = r.subtitulo, !s.isEmpty {
                                    Text(s).font(Tema.Fuente.nota).foregroundStyle(Tema.Color.textoSecundario).lineLimit(2)
                                }
                            }
                        } icon: {
                            Image(systemName: icono).foregroundStyle(Tema.Color.primario)
                        }
                    }
                }
            }
            .filaLista()
        }
    }

    private func buscar() async {
        guard consulta.count >= 2 else { resultados = nil; error = nil; return }
        // Espera a que se deje de escribir; si cambia el texto, esta tarea se cancela.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        buscando = true
        defer { buscando = false }
        do {
            let r = try await sesion.api.enviar(.buscar(consulta))
            guard !Task.isCancelled else { return }
            resultados = r
            error = nil
        } catch .noAutorizado {
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
}

/// Abre el detalle de un piso a partir de su id (destino de la búsqueda).
struct PisoDestinoView: View {
    @Environment(SesionStore.self) private var sesion
    let id: Int
    @State private var estado: EstadoCarga<Piso> = .cargando

    var body: some View {
        VistaCarga(estado: estado, reintentar: { Task { await cargar() } }) { PisoDetalleView(piso: $0) }
            .task { await cargar() }
    }

    private func cargar() async {
        do { estado = .cargado(try await sesion.api.enviar(.piso(id: id))) }
        catch .noAutorizado {}
        catch { estado = .error(error.localizedDescription) }
    }
}
