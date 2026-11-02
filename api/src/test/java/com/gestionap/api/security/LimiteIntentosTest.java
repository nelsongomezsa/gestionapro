package com.gestionap.api.security;

import com.gestionap.api.web.ApiException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.catchThrowableOfType;

class LimiteIntentosTest {

    /** Reloj que se puede adelantar a mano. */
    static class Reloj extends Clock {
        Instant ahora = Instant.parse("2026-10-31T10:00:00Z");
        @Override public java.time.ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(java.time.ZoneId z) { return this; }
        @Override public Instant instant() { return ahora; }
    }

    final Reloj reloj = new Reloj();
    final LimiteIntentos limites = new LimiteIntentos(Duration.ofMinutes(15), 3, 2, reloj);

    @Test
    void porIp_alSuperarElMaximo_429ConSegundosHastaQueAcabeLaVentana() {
        for (int i = 0; i < 3; i++) limites.comprobar("1.1.1.1", "a" + i + "@x.com");
        reloj.ahora = reloj.ahora.plusSeconds(60);

        ApiException e = catchThrowableOfType(ApiException.class, () -> limites.comprobar("1.1.1.1", "otro@x.com"));

        assertThat(e.getStatus()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(e.getReintentarEn()).isEqualTo(14 * 60);
        assertThat(e.getMessage()).isEqualTo("Demasiados intentos. Prueba de nuevo en 14 minutos");
        // Otra IP no se ve afectada.
        assertThatCode(() -> limites.comprobar("2.2.2.2", "otro@x.com")).doesNotThrowAnyException();
    }

    @Test
    void porEmail_cuentaIntentos_yUnAciertoLosBorra() {
        limites.comprobar("1.1.1.1", "Ana@X.com");
        limites.acierto("ana@x.com");
        limites.comprobar("2.2.2.2", "ana@x.com");
        limites.comprobar("3.3.3.3", "ana@x.com");

        // Desde otra IP también se bloquea: el límite es del email.
        assertThat(catchThrowableOfType(ApiException.class, () -> limites.comprobar("9.9.9.9", " ANA@x.com "))
                .getCodigo()).isEqualTo("DEMASIADOS_INTENTOS");
    }

    @Test
    void alCaducarLaVentana_sePuedeVolverAIntentar() {
        limites.comprobar("1.1.1.1", "ana@x.com");
        limites.comprobar("1.1.1.1", "ana@x.com");
        reloj.ahora = reloj.ahora.plus(Duration.ofMinutes(15));

        assertThatCode(() -> limites.comprobar("1.1.1.1", "ana@x.com")).doesNotThrowAnyException();
    }

    @Test
    void usuario_concurrencia_reservaExactamenteElMaximo() throws Exception {
        LimiteIntentos concurrentes = new LimiteIntentos(Duration.ofMinutes(15), 100, 5, reloj);
        ExecutorService pool = Executors.newFixedThreadPool(50);
        CountDownLatch inicio = new CountDownLatch(1);
        AtomicInteger pasan = new AtomicInteger();
        AtomicInteger rechazados = new AtomicInteger();
        for (int i = 0; i < 50; i++) pool.submit(() -> {
            try {
                inicio.await();
                concurrentes.comprobarUsuario(1);
                pasan.incrementAndGet();
            } catch (ApiException e) {
                rechazados.incrementAndGet();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });
        inicio.countDown();
        pool.shutdown();
        org.awaitility.Awaitility.await().until(pool::isTerminated);
        assertThat(pasan.get()).isEqualTo(5);
        assertThat(rechazados.get()).isEqualTo(45);
    }
}
