package com.gestionap.api.service;

import com.gestionap.api.IntegrationTest;
import com.gestionap.api.domain.*;
import com.gestionap.api.repository.NotificacionRepository;
import com.gestionap.api.security.UsuarioAutenticado;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Limit;
import com.gestionap.api.repository.ContratoRepository;
import com.gestionap.api.repository.PagoRepository;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/** Cobro vencido (propietario), recordatorio y retraso (inquilino) y email de recordatorio, con fechas fijas. */
class AvisosCobroTest extends IntegrationTest {

    @Autowired NotificacionService servicio;
    @Autowired NotificacionRepository notificaciones;
    @Autowired ContratoRepository contratos;
    @Autowired PagoRepository pagos;

    /** Email de mentira: guarda lo que "envía" (sin otro contexto de Spring con un mock). */
    static class EmailFalso extends EmailService {
        final boolean configurado;
        final List<String> enviados = new ArrayList<>();

        EmailFalso(boolean configurado) {
            super(null, "", "");
            this.configurado = configurado;
        }

        @Override public boolean estaConfigurado() { return configurado; }

        @Override public boolean enviar(String destinatario, String asunto, String cuerpo) {
            enviados.add(destinatario + " | " + asunto + " | " + cuerpo);
            return true;
        }
    }

    UsuarioAutenticado ana;
    UsuarioAutenticado lucia;
    Contrato contrato;

    @BeforeEach
    void preparar() {
        Usuario propietaria = datos.usuario("ana@test.com", Rol.PROPIETARIO);
        Habitacion h = datos.habitacion(datos.piso("Calle de Ana 1", datos.ciudad("Madrid"), propietaria), 1,
                EstadoHabitacion.alquilada);
        Inquilino inq = datos.inquilino("11111111A", "lucia@correo.test");
        Usuario cuenta = datos.usuario("lucia@test.com", Rol.INQUILINO);
        inq.setUsuario(cuenta);
        contrato = datos.contrato(h, inq, "450.00", LocalDate.of(2030, 1, 1), LocalDate.of(2030, 12, 31));
        ana = new UsuarioAutenticado(propietaria.getId(), propietaria.getEmail(), "Ana", Rol.PROPIETARIO);
        lucia = new UsuarioAutenticado(cuenta.getId(), cuenta.getEmail(), "Lucía", Rol.INQUILINO);
    }

    private List<String> tipos(UsuarioAutenticado u) {
        return notificaciones.findByIdUsuarioOrderByFechaDescIdDesc(u.id(), Limit.of(50)).stream()
                .map(Notificacion::getTipo).toList();
    }

    @Test
    void propietario_cobroVencidoSoloPasadoElDia7_yUnaVezPorMes() {
        servicio.generar(ana, LocalDate.of(2030, 3, 7));
        assertThat(tipos(ana)).contains("pago_pendiente").doesNotContain("cobro_vencido");
        servicio.generar(ana, LocalDate.of(2030, 3, 8));
        servicio.generar(ana, LocalDate.of(2030, 3, 20));
        assertThat(tipos(ana)).filteredOn("cobro_vencido"::equals).hasSize(1);
        // El "pendiente" de antes del límite no se vuelve a crear después.
        assertThat(tipos(ana)).filteredOn("pago_pendiente"::equals).hasSize(1);
        var n = notificaciones.findByIdUsuarioOrderByFechaDescIdDesc(ana.id(), Limit.of(50)).stream()
                .filter(x -> x.getTipo().equals("cobro_vencido")).findFirst().orElseThrow();
        assertThat(n.getDescripcion()).contains("450,00").contains("vencía el 7 de marzo (hace 1 día)");
    }

    @Test
    void propietario_sinAvisoSiHayPagoOElContratoEmpezoDespuesDelLimite() {
        datos.pago(contrato, "450.00", LocalDate.of(2030, 4, 2));
        servicio.generar(ana, LocalDate.of(2030, 4, 15));
        assertThat(tipos(ana)).doesNotContain("cobro_vencido");

        contrato.setFechaInicio(LocalDate.of(2030, 5, 20));
        servicio.generar(ana, LocalDate.of(2030, 5, 25));
        assertThat(tipos(ana)).doesNotContain("cobro_vencido");
    }

    @Test
    void inquilino_recordatorioTresDiasAntes_yRetrasoDespues() {
        servicio.generar(lucia, LocalDate.of(2030, 3, 3));
        assertThat(tipos(lucia)).isEmpty();
        servicio.generar(lucia, LocalDate.of(2030, 3, 4));
        servicio.generar(lucia, LocalDate.of(2030, 3, 7));
        assertThat(tipos(lucia)).containsExactly("recordatorio_pago");
        servicio.generar(lucia, LocalDate.of(2030, 3, 9));
        assertThat(tipos(lucia)).containsExactlyInAnyOrder("recordatorio_pago", "pago_atrasado");
        // Nunca los avisos del propietario.
        assertThat(tipos(lucia)).doesNotContain("cobro_vencido", "pago_pendiente");
    }

    @Test
    void email_unaVezPorContratoYMes_yQuedaAnotadoParaElPropietario() {
        var email = new EmailFalso(true);
        var recordatorios = new RecordatoriosPago(contratos, pagos, servicio, email);
        assertThat(recordatorios.enviar(LocalDate.of(2030, 3, 2))).isZero();   // aún no toca
        assertThat(recordatorios.enviar(LocalDate.of(2030, 3, 5))).isEqualTo(1);
        assertThat(recordatorios.enviar(LocalDate.of(2030, 3, 6))).isZero();   // ya enviado
        assertThat(recordatorios.enviar(LocalDate.of(2030, 3, 8))).isZero();   // pasado el límite
        assertThat(email.enviados).singleElement().asString()
                .startsWith("lucia@correo.test").contains("marzo").contains("450,00");
        assertThat(tipos(ana)).contains("recordatorio_enviado");
    }

    @Test
    void email_sinConfigurar_noEnviaNada() {
        var email = new EmailFalso(false);
        assertThat(new RecordatoriosPago(contratos, pagos, servicio, email).enviar(LocalDate.of(2030, 3, 5))).isZero();
        assertThat(email.enviados).isEmpty();
    }
}
