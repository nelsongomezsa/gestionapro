package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/** Código de invitación de un solo uso para que un inquilino cree su cuenta (migración V1). */
@Entity
@Table(name = "Invitaciones")
@Getter
@Setter
@NoArgsConstructor
public class Invitacion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_invitacion")
    private Integer id;

    /** SHA-256 hex del código; el código en claro solo se devuelve al crearla. */
    @Column(name = "codigo_hash", nullable = false, unique = true, length = 64, columnDefinition = "char(64)")
    private String codigoHash;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_inquilino", nullable = false)
    private Inquilino inquilino;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_creador", nullable = false)
    private Usuario creador;

    @Column(name = "fecha_creacion", nullable = false)
    private LocalDateTime fechaCreacion;

    @Column(name = "fecha_expiracion", nullable = false)
    private LocalDateTime fechaExpiracion;

    @Column(name = "fecha_uso")
    private LocalDateTime fechaUso;

    public boolean esUsable(LocalDateTime ahora) {
        return fechaUso == null && ahora.isBefore(fechaExpiracion);
    }
}
