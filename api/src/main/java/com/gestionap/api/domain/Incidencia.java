package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "Incidencias")
@Getter
@Setter
@NoArgsConstructor
public class Incidencia {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_incidencia")
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_habitacion", nullable = false)
    private Habitacion habitacion;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_inquilino", nullable = false)
    private Inquilino inquilino;

    @Column(name = "descripcion", nullable = false, length = 255)
    private String descripcion;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado", nullable = false, columnDefinition = "enum('pendiente','en_proceso','resuelta')")
    private EstadoIncidencia estado = EstadoIncidencia.pendiente;

    @Column(name = "fecha", nullable = false)
    private LocalDate fecha;

    @Column(name = "coste_reparacion", precision = 8, scale = 2)
    private BigDecimal costeReparacion = BigDecimal.ZERO;
}
