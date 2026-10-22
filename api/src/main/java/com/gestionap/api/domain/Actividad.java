package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/**
 * Log de actividad compartido con el escritorio (ActividadDAO). En la BD real
 * la tabla se llama "actividad" en minúsculas y sus columnas admiten NULL.
 */
@Entity
@Table(name = "actividad")
@Getter
@Setter
@NoArgsConstructor
public class Actividad {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Integer id;

    @Column(name = "id_usuario")
    private Integer idUsuario;

    @Column(name = "accion", length = 100)
    private String accion;

    @Column(name = "descripcion", length = 255)
    private String descripcion;

    @Column(name = "fecha")
    private LocalDateTime fecha;
}
