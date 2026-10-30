import PhotosUI
import SwiftUI

/// Fotos de una incidencia. El estado vive en la pantalla (dentro de una List, un .task en la
/// sección se repetiría por fila).
@MainActor @Observable
final class ModeloFotos {
    var fotos: [FotoIncidencia] = []
    var imagenes: [Int: UIImage] = [:]
    var seleccion: [PhotosPickerItem] = []
    var subiendo = false
    var ampliada: FotoIncidencia?
    var error: String?

    static let maximo = 10

    func cargar(incidencia id: Int, con api: APIClient) async {
        do {
            fotos = try await api.enviar(.fotosIncidencia(id))
            for f in fotos where imagenes[f.id] == nil {
                if let datos = try? await api.descargar(Rutas.fotoIncidencia(f.id), tipo: f.tipo) {
                    imagenes[f.id] = UIImage(data: datos)
                }
            }
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }

    func subirSeleccion(incidencia id: Int, con api: APIClient) async {
        guard !seleccion.isEmpty else { return }
        subiendo = true
        defer {
            subiendo = false
            seleccion = []
        }
        for item in seleccion.prefix(max(0, Self.maximo - fotos.count)) {
            guard let datos = try? await item.loadTransferable(type: Data.self), let jpeg = FotoPreparada.jpeg(datos) else {
                error = "No se pudo leer una de las fotos"
                continue
            }
            do {
                let f = try await api.subir(Rutas.fotosIncidencia(id), archivo: jpeg, nombre: "foto.jpg", tipo: "image/jpeg",
                                            respuesta: FotoIncidencia.self)
                fotos.append(f)
                imagenes[f.id] = UIImage(data: jpeg)
            } catch .noAutorizado {
                return
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func borrar(_ f: FotoIncidencia, con api: APIClient) async {
        do {
            _ = try await api.enviar(.borrarFotoIncidencia(f.id))
            fotos.removeAll { $0.id == f.id }
            imagenes[f.id] = nil
            ampliada = nil
        } catch .noAutorizado {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Sección "Fotos": miniaturas y botón para añadir desde la fototeca.
struct SeccionFotos: View {
    @Bindable var modelo: ModeloFotos
    @ScaledMetric private var lado: CGFloat = 96

    var body: some View {
        Section {
            if !modelo.fotos.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: lado), spacing: Tema.Espacio.xs)], spacing: Tema.Espacio.xs) {
                    ForEach(Array(modelo.fotos.enumerated()), id: \.element.id) { indice, f in
                        Button { modelo.ampliada = f } label: {
                            miniatura(f)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Foto \(indice + 1) de \(modelo.fotos.count)")
                        .accessibilityHint("Abre la foto")
                    }
                }
                .padding(.vertical, Tema.Espacio.xxs)
            }
            if modelo.fotos.count < ModeloFotos.maximo {
                // La etiqueta del selector es un cierre Sendable: se le pasan valores, no el modelo.
                let subiendo = modelo.subiendo
                let texto = modelo.fotos.isEmpty ? "Añadir fotos" : "Añadir más fotos"
                PhotosPicker(selection: $modelo.seleccion, maxSelectionCount: ModeloFotos.maximo - modelo.fotos.count,
                             matching: .images) {
                    if subiendo {
                        HStack { ProgressView(); Text("Subiendo…") }
                    } else {
                        Label(texto, systemImage: "photo.badge.plus")
                    }
                }
                .disabled(modelo.subiendo)
                .accessibilityIdentifier("botonAnadirFotos")
            }
        } header: {
            Text(modelo.fotos.isEmpty ? "Fotos" : "Fotos (\(modelo.fotos.count))")
        } footer: {
            if modelo.fotos.isEmpty { Text("Una foto ayuda a entender el problema y a presupuestar la reparación.") }
        }
        .filaLista()
    }

    @ViewBuilder
    private func miniatura(_ f: FotoIncidencia) -> some View {
        Group {
            if let imagen = modelo.imagenes[f.id] {
                Image(uiImage: imagen).resizable().scaledToFill()
            } else {
                Tema.Color.superficieElevada.overlay(ProgressView())
            }
        }
        .frame(width: lado, height: lado)
        .clipShape(.rect(cornerRadius: Tema.Radio.medio))
        .contentShape(.rect)
    }
}

extension View {
    /// Carga las fotos, sube las elegidas y muestra la ampliada; se pone en la pantalla.
    func fotosIncidencia(_ modelo: ModeloFotos, incidencia id: Int, api: APIClient, puedeBorrarTodas: Bool) -> some View {
        @Bindable var modelo = modelo
        return self
            .task(id: id) { await modelo.cargar(incidencia: id, con: api) }
            .onChange(of: modelo.seleccion) { _, _ in Task { await modelo.subirSeleccion(incidencia: id, con: api) } }
            .sheet(item: $modelo.ampliada) { f in
                NavigationStack {
                    Group {
                        if let imagen = modelo.imagenes[f.id] {
                            Image(uiImage: imagen).resizable().scaledToFit()
                                .accessibilityLabel("Foto de la incidencia")
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Tema.Color.fondo)
                    .navigationTitle(f.fecha.formatted(FormatoFecha.corta))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { modelo.ampliada = nil } }
                        if puedeBorrarTodas || f.mia {
                            ToolbarItem(placement: .destructiveAction) {
                                Button("Borrar", systemImage: "trash", role: .destructive) {
                                    Task { await modelo.borrar(f, con: api) }
                                }
                            }
                        }
                    }
                }
            }
            .alertaError($modelo.error)
    }
}
