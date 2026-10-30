package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/** Foto de una incidencia (el archivo va en disco; aquí su ruta). Tabla nueva, V6. */
@Entity
@Table(name = "FotosIncidencia")
@Getter
@Setter
@NoArgsConstructor
public class FotoIncidencia {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_foto")
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_incidencia", nullable = false)
    private Incidencia incidencia;

    @Column(name = "ruta", nullable = false)
    private String ruta;

    @Column(name = "tipo", nullable = false, length = 50)
    private String tipo;

    @Column(name = "id_usuario")
    private Integer idUsuario;

    @Column(name = "fecha", nullable = false)
    private LocalDateTime fecha;
}
