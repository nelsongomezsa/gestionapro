package com.gestionap.api.config;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.env.ConfigurableEnvironment;

/**
 * Impide arrancar sin un perfil activo explícito (dev, prod...). Antes "dev"
 * era el perfil por defecto: desplegar sin SPRING_PROFILES_ACTIVE=prod
 * habría usado el secreto JWT de desarrollo, que es público en el repo.
 *
 * <p>Se ejecuta después de cargar la configuración (LOWEST_PRECEDENCE), así
 * que cuenta cualquier forma de activar perfiles: --spring.profiles.active,
 * SPRING_PROFILES_ACTIVE o @ActiveProfiles en los tests.
 */
public class PerfilObligatorio implements EnvironmentPostProcessor, Ordered {

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment env, SpringApplication app) {
        if (env.getActiveProfiles().length == 0) {
            throw new IllegalStateException("No hay ningún perfil activo. Arranca con un perfil explícito: "
                    + "--spring.profiles.active=dev (local) o SPRING_PROFILES_ACTIVE=prod (despliegue).");
        }
    }

    @Override
    public int getOrder() {
        return Ordered.LOWEST_PRECEDENCE;
    }
}
