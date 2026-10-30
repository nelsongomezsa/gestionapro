package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "Usuarios")
@Getter
@Setter
@NoArgsConstructor
public class Usuario {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_usuario")
    private Integer id;

    @Column(name = "nombre", nullable = false, length = 100)
    private String nombre;

    @Column(name = "email", nullable = false, length = 100)
    private String email;

    /** Añadido en la migración V1; opcional (lo usa el contrato en PDF). */
    @Column(name = "dni", length = 20)
    private String dni;

    /** Migración V2. IBAN para el QR de pago SEPA de sus inquilinos; opcional. */
    @Column(name = "iban", length = 34)
    private String iban;

    /** BCrypt; las filas antiguas pueden tener SHA-256 hex (ver LegacyPasswordEncoder). */
    @Column(name = "password_hash", nullable = false, length = 64)
    private String passwordHash;

    @Convert(converter = Rol.Converter.class)
    @Column(name = "rol", nullable = false, columnDefinition = "enum('admin','usuario','inquilino')")
    private Rol rol;

    @Column(name = "activo", nullable = false)
    private boolean activo = true;
}
