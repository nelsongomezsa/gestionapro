import MapKit
import SwiftUI

/// Mapa con todos los pisos, con el color del semáforo. Las direcciones se sitúan en el
/// propio dispositivo con MapKit (en escritorio se abría Google Maps de uno en uno).
struct MapaPisosView: View {
    let pisos: [Piso]

    @State private var situados: [(piso: Piso, coordenada: CLLocationCoordinate2D)] = []
    @State private var buscando = true
    @State private var elegido: Piso?

    var body: some View {
        Map {
            ForEach(situados, id: \.piso.id) { s in
                Annotation(s.piso.direccion, coordinate: s.coordenada) {
                    Button { elegido = s.piso } label: {
                        Image(systemName: "building.2.fill")
                            .font(Tema.Fuente.nota.weight(.bold))
                            .foregroundStyle(Tema.Color.sobrePrimario)
                            .frame(width: Tema.Tamano.iconoPequeno, height: Tema.Tamano.iconoPequeno)
                            .background((s.piso.metricas?.calificacion).tono.color, in: .circle)
                            .overlay(Circle().strokeBorder(Tema.Color.sobrePrimario, lineWidth: 2))
                    }
                    .accessibilityLabel("\(s.piso.direccion), \((s.piso.metricas?.calificacion).texto)")
                }
            }
        }
        .mapControls { MapCompass(); MapScaleView() }
        .overlay(alignment: .top) {
            if buscando {
                Label("Situando \(pisos.count) pisos…", systemImage: "location.magnifyingglass")
                    .font(Tema.Fuente.detalle).padding(Tema.Espacio.s)
                    .background(.regularMaterial, in: .capsule).padding(Tema.Espacio.m)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let p = elegido {
                NavigationLink(value: p) { TarjetaPiso(piso: p) }
                    .buttonStyle(.plain)
                    .padding(Tema.Espacio.m)
            }
        }
        .navigationTitle("Mapa de pisos")
        .navigationBarTitleDisplayMode(.inline)
        .task { await situar() }
    }

    private func situar() async {
        defer { buscando = false }
        for p in pisos {
            // .task se cancela al salir de la pantalla: no seguir situando pisos.
            if Task.isCancelled { break }
            let peticion = MKLocalSearch.Request()
            peticion.naturalLanguageQuery = "\(p.direccion), \(p.ciudad.nombre), España"
            if let item = try? await MKLocalSearch(request: peticion).start().mapItems.first {
                situados.append((p, item.placemark.coordinate))
            }
        }
    }
}
