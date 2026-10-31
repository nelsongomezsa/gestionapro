package com.gestionap.api.security;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;

class ContrasenasFiltradasTest {

    HttpServer servidor;
    final AtomicReference<String> rutaPedida = new AtomicReference<>();
    final AtomicReference<String> relleno = new AtomicReference<>();

    String arrancar(int status, String cuerpo) throws Exception {
        servidor = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        servidor.createContext("/range/", ex -> {
            rutaPedida.set(ex.getRequestURI().getPath());
            relleno.set(ex.getRequestHeaders().getFirst("Add-Padding"));
            byte[] b = cuerpo.getBytes(StandardCharsets.UTF_8);
            ex.sendResponseHeaders(status, b.length);
            ex.getResponseBody().write(b);
            ex.close();
        });
        servidor.start();
        return "http://127.0.0.1:" + servidor.getAddress().getPort() + "/range/";
    }

    @AfterEach
    void parar() {
        if (servidor != null) servidor.stop(0);
    }

    @Test
    void soloEnviaLosCincoPrimerosDelSha1_yDetectaLaFiltrada() throws Exception {
        String sha1 = ContrasenasFiltradas.sha1("password1234");
        var hibp = new ContrasenasFiltradas(arrancar(200, "0000000000000000000000000000000000A:3\r\n" + sha1.substring(5) + ":2531\r\n"));

        assertThat(hibp.filtrada("password1234")).isTrue();
        assertThat(rutaPedida.get()).isEqualTo("/range/" + sha1.substring(0, 5));
        assertThat(relleno.get()).isEqualTo("true");
    }

    @Test
    void noFiltrada_niLasLineasDeRellenoConCero() throws Exception {
        String sha1 = ContrasenasFiltradas.sha1("Una-frase-larga-y-rara-2026");
        var hibp = new ContrasenasFiltradas(arrancar(200, sha1.substring(5) + ":0\r\nABCDEF0123456789ABCDEF0123456789ABC:12\r\n"));

        assertThat(hibp.filtrada("Una-frase-larga-y-rara-2026")).isFalse();
    }

    @Test
    void siHibpFallaOEstaCaido_noBloquea() throws Exception {
        assertThat(new ContrasenasFiltradas(arrancar(503, "")).filtrada("password1234")).isFalse();
        parar();
        assertThat(new ContrasenasFiltradas("http://127.0.0.1:1/range/").filtrada("password1234")).isFalse();
        assertThat(new ContrasenasFiltradas("").filtrada("password1234")).isFalse();
    }
}
