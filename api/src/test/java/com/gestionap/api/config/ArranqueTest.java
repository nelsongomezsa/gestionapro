package com.gestionap.api.config;

import com.gestionap.api.GestionaproApiApplication;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.context.ConfigurableApplicationContext;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/** Arranca la aplicación real para comprobar las guardas de configuración. */
class ArranqueTest {

    @BeforeAll
    static void sinVariablesQueInterfieran() {
        assumeTrue(System.getenv("JWT_SECRET") == null, "JWT_SECRET está definida en el entorno de esta máquina");
        assumeTrue(System.getenv("SPRING_PROFILES_ACTIVE") == null, "SPRING_PROFILES_ACTIVE está definida");
    }

    /**
     * Arranca en prod con H2 en memoria en lugar de MariaDB; lo demás, la configuración real.
     * Van como argumentos de línea de comandos para que tengan más precedencia que application.yml.
     */
    private static ConfigurableApplicationContext arrancarProd(String... extra) {
        List<String> args = new ArrayList<>(List.of(
                "--DB_URL=jdbc:h2:mem:" + UUID.randomUUID() + ";MODE=MySQL",
                "--DB_USER=sa",
                "--DB_PASS=",
                "--spring.jpa.hibernate.ddl-auto=none",
                "--server.port=0"));
        for (String e : extra) args.add("--" + e);
        // Servlet en puerto aleatorio: SecurityConfig necesita el contexto web.
        return new SpringApplicationBuilder(GestionaproApiApplication.class)
                .profiles("prod")
                .run(args.toArray(String[]::new));
    }

    private static String mensajes(Throwable t) {
        StringBuilder sb = new StringBuilder();
        for (Throwable c = t; c != null; c = c.getCause()) sb.append(c.getMessage()).append('\n');
        return sb.toString();
    }

    @Test
    void sinPerfilActivo_noArranca() {
        var app = new SpringApplicationBuilder(GestionaproApiApplication.class).web(WebApplicationType.NONE);

        assertThatThrownBy(app::run)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("No hay ningún perfil activo");
    }

    @Test
    void prod_sinJwtSecret_noArranca() {
        assertThatThrownBy(ArranqueTest::arrancarProd)
                .satisfies(e -> assertThat(mensajes(e)).contains("JWT_SECRET"));
    }

    @Test
    void prod_conJwtSecretDemasiadoCorto_noArranca() {
        assertThatThrownBy(() -> arrancarProd("JWT_SECRET=corto"))
                .satisfies(e -> assertThat(mensajes(e)).contains("JWT_SECRET debe tener al menos 32 caracteres"));
    }

    @Test
    void prod_conTodaLaConfiguracion_arranca() {
        try (ConfigurableApplicationContext ctx = arrancarProd("JWT_SECRET=" + "x".repeat(48))) {
            assertThat(ctx.getEnvironment().getActiveProfiles()).containsExactly("prod");
        }
    }
}
