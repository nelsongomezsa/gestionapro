package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/** Simulación de la calculadora guardada con nombre (tabla nueva, V11). */
@Entity
@Table(name = "AnalisisInversion")
@Getter
@Setter
@NoArgsConstructor
public class AnalisisInversion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_analisis")
    private Integer id;

    @Column(name = "id_usuario", nullable = false)
    private Integer idUsuario;

    @Column(name = "id_piso")
    private Integer idPiso;

    @Column(name = "nombre", nullable = false, length = 80)
    private String nombre;

    /** Entrada de la calculadora en JSON (RentabilidadRequest validada). */
    @Column(name = "datos", nullable = false, length = 2000)
    private String datos;

    @Column(name = "fecha_creacion", nullable = false)
    private LocalDateTime fechaCreacion;

    @Column(name = "fecha_actualizacion", nullable = false)
    private LocalDateTime fechaActualizacion;
}
