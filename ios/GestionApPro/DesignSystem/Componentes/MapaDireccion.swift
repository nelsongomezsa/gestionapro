import MapKit
import SwiftUI

/// Mapa de una dirección (en escritorio se abría Google Maps en el navegador).
/// La dirección se busca en el propio dispositivo con MapKit; no hace falta guardar coordenadas.
struct MapaDireccion: View {
    let titulo: String
    let direccion: String
    let ciudad: String

    @State private var lugar: MKMapItem?
    @State private var posicion: MapCameraPosition = .automatic
    @State private var noEncontrada = false

    var body: some View {
        Group {
            if let lugar {
                Map(position: $posicion) {
                    Marker(titulo, systemImage: "building.2.fill", coordinate: lugar.placemark.coordinate)
                        .tint(Tema.Color.primario)
                }
                .mapControls { MapCompass(); MapScaleView() }
                .safeAreaInset(edge: .bottom) {
                    Button { lugar.openInMaps() } label: {
                        Label("Abrir en Mapas", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Tema.Color.primarioRelleno)
                    .controlSize(.large)
                    .padding()
                }
            } else if noEncontrada {
                EstadoVacio(icono: "mappin.slash", titulo: "Dirección no encontrada",
                            mensaje: "No se ha podido situar «\(direccion), \(ciudad)» en el mapa.")
            } else {
                ProgressView("Buscando la dirección…")
            }
        }
        .navigationTitle(titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task { await buscar() }
    }

    private func buscar() async {
        let peticion = MKLocalSearch.Request()
        peticion.naturalLanguageQuery = "\(direccion), \(ciudad), España"
        do {
            let respuesta = try await MKLocalSearch(request: peticion).start()
            if let primero = respuesta.mapItems.first {
                primero.name = titulo
                lugar = primero
                posicion = .region(MKCoordinateRegion(center: primero.placemark.coordinate,
                                                      latitudinalMeters: 600, longitudinalMeters: 600))
            } else {
                noEncontrada = true
            }
        } catch {
            noEncontrada = true
        }
    }
}
