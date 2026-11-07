package com.gestionap.api.security;

import com.gestionap.api.service.EmailServiceAccesor;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

/** Configuración y utilidades de la auditoría: sin credenciales en el repositorio ni datos personales en logs. */
class ConfiguracionSeguraTest {

    /** Todos los perfiles toman usuario y contraseña de la base de variables de entorno. */
    @Test
    void credencialesDeLaBase_porVariablesDeEntorno() throws Exception {
        for (String perfil : new String[]{"application-dev.yml", "application-prod.yml"}) {
            String yml = Files.readString(Path.of("src/main/resources", perfil));
            assertThat(yml).as(perfil).containsPattern("username: \\$\\{DB_USER")
                    .containsPattern("password: \\$\\{DB_PASS");
        }
    }

    @Test
    void elEmailNoVaEnClaroALosLogs() {
        assertThat(EmailServiceAccesor.enmascarar("ana.garcia@example.com")).isEqualTo("a***@example.com");
        assertThat(EmailServiceAccesor.enmascarar("sin-arroba")).isEqualTo("***");
    }

    @Test
    void csv_neutralizaFormulasTambienConTabuladorYRetorno() {
        for (String ataque : new String[]{"=HYPERLINK(\"http://x\")", "+1+1", "-2", "@SUM(A1)", "\t=1", "\r=1"}) {
            assertThat(EmailServiceAccesor.celdaCsv(ataque)).as(ataque).startsWith("\"'");
        }
        assertThat(EmailServiceAccesor.celdaCsv("IBI \"anual\"")).isEqualTo("\"IBI \"\"anual\"\"\"");
    }
}
