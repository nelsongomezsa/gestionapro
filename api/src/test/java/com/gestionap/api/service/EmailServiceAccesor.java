package com.gestionap.api.service;

/** Acceso desde los tests de seguridad a utilidades internas (paquete service). */
public final class EmailServiceAccesor {
    private EmailServiceAccesor() {}
    public static String enmascarar(String email) { return EmailService.enmascarar(email); }
    public static String celdaCsv(String texto) { return ResumenFiscalService.celdaCsv(texto); }
}
