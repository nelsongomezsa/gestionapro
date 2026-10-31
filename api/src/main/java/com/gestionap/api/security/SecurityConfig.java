package com.gestionap.api.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    SecurityFilterChain filtros(HttpSecurity http, JwtAuthenticationFilter jwtFilter,
                                JsonSecurityErrorHandler errores) throws Exception {
        return http
                // API sin sesión ni cookies: CSRF no aplica con tokens Bearer.
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.POST, "/api/auth/login", "/api/auth/register-inquilino").permitAll()
                        .requestMatchers("/swagger-ui.html", "/swagger-ui/**", "/v3/api-docs/**").permitAll()
                        .requestMatchers("/error").permitAll()
                        .requestMatchers(HttpMethod.GET, "/actuator/health").permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(e -> e.authenticationEntryPoint(errores).accessDeniedHandler(errores))
                .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
                .build();
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new LegacyPasswordEncoder();
    }

    /** Evita que Spring Boot cree un usuario por defecto con contraseña en el log. */
    @Bean
    UserDetailsService sinUsuariosEnMemoria() {
        return new InMemoryUserDetailsManager();
    }
}
