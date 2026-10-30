package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/** Tabla Notificaciones del escritorio (NotificacionDAO). */
@Entity
@Table(name = "Notificaciones")
@Getter
@Setter
@NoArgsConstructor
public class Notificacion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_notificacion")
    private Integer id;

    /** contrato_vence, pago_pendiente, incidencia_antigua, mantenimiento_largo. */
    @Column(name = "tipo", nullable = false, length = 50)
    private String tipo;

    @Column(name = "titulo", nullable = false, length = 200)
    private String titulo;

    @Column(name = "descripcion", columnDefinition = "text")
    private String descripcion;

    /** Clave del escritorio para no repetir avisos: "contrato_vence_12", "pago_pendiente_12_2026_10"... */
    @Column(name = "referencia", length = 100)
    private String referencia;

    @Column(name = "fecha", nullable = false)
    private LocalDateTime fecha;

    @Column(name = "leida", nullable = false)
    private boolean leida;

    @Column(name = "id_usuario", nullable = false)
    private Integer idUsuario;
}
