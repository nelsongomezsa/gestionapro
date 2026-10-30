import Foundation

/// GET /api/buscar?q= : hasta 10 resultados por grupo, solo de lo que el usuario puede ver.
struct ResultadosBusqueda: Decodable, Sendable {
    let pisos: [Resultado]
    let inquilinos: [Resultado]
    let contratos: [Resultado]
    let incidencias: [Resultado]

    struct Resultado: Decodable, Hashable, Sendable {
        let id: Int
        let titulo: String
        let subtitulo: String?
    }

    var vacio: Bool { pisos.isEmpty && inquilinos.isEmpty && contratos.isEmpty && incidencias.isEmpty }
}
