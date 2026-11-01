import Foundation
import Testing
@testable import GestionApPro

struct AjustesTests {
    @Test func csv_escapaSeparadoresComillasYFormulas() {
        #expect(ExportarDatos.campo("Calle Mayor; 3") == "\"Calle Mayor; 3\"")
        #expect(ExportarDatos.campo("Dice \"hola\"") == "\"Dice \"\"hola\"\"\"")
        #expect(ExportarDatos.campo("=HYPERLINK(\"x\")") == "\"'=HYPERLINK(\"\"x\"\")\"")
        #expect(ExportarDatos.campo("-12") == "'-12")
        #expect(ExportarDatos.campo("Normal") == "Normal")
    }

    @Test func csv_cabeceraYFilasConCRLF() {
        let csv = ExportarDatos.filas(["A", "B"], [["1", "2"], ["3", "4"]])
        #expect(csv == "A;B\r\n1;2\r\n3;4\r\n")
    }

    @Test func pestanaInicial_seAjustaAlRol() {
        #expect(Pestana.de(.cobros, gestiona: true) == .cobros)
        #expect(Pestana.de(.cobros, gestiona: false) == .alquiler)
        #expect(Pestana.de(.alquiler, gestiona: true) == .inicio)
        #expect(Pestana.de(.mensajes, gestiona: false) == .mensajes)
    }
}
