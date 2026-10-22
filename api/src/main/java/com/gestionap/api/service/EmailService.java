package com.gestionap.api.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

/**
 * Envío de emails con spring-boot-starter-mail. Configuración por variables
 * de entorno (MAIL_HOST, MAIL_USER, MAIL_PASS...). Si no está configurado
 * (lo normal en dev) no falla: registra el aviso y devuelve false.
 */
@Slf4j
@Service
public class EmailService {

    private final ObjectProvider<JavaMailSender> mailSender;
    private final String host;
    private final String remitente;

    public EmailService(ObjectProvider<JavaMailSender> mailSender,
                        @Value("${spring.mail.host:}") String host,
                        @Value("${gestionap.mail.remitente:}") String remitente) {
        this.mailSender = mailSender;
        this.host = host;
        this.remitente = remitente;
    }

    public boolean estaConfigurado() {
        return !host.isBlank() && mailSender.getIfAvailable() != null;
    }

    public boolean enviar(String destinatario, String asunto, String cuerpo) {
        if (!estaConfigurado()) {
            log.info("Email sin configurar: no se envía '{}' a {}", asunto, destinatario);
            return false;
        }
        SimpleMailMessage msg = new SimpleMailMessage();
        if (!remitente.isBlank()) msg.setFrom(remitente);
        msg.setTo(destinatario);
        msg.setSubject(asunto);
        msg.setText(cuerpo);
        try {
            mailSender.getObject().send(msg);
            return true;
        } catch (MailException e) {
            log.warn("No se pudo enviar el email '{}' a {}: {}", asunto, destinatario, e.getMessage());
            return false;
        }
    }
}
