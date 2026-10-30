package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/** Una actualización anual de la renta confirmada por el propietario (tabla nueva, V5). */
@Entity
@Table(name = "ActualizacionesRenta")
@Getter
@Setter
@NoArgsConstructor
public class ActualizacionRenta {

    /** IRAV e IPC son los del INE; PACTADO, un porcentaje que pone el propietario. */
    public enum Indice { IRAV, IPC, PACTADO }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_actualizacion")
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_contrato", nullable = false)
    private Contrato contrato;

    @Column(name = "fecha_efecto", nullable = false)
    private LocalDate fechaEfecto;

    @Enumerated(EnumType.STRING)
    @Column(name = "indice", nullable = false, length = 10)
    private Indice indice;

    /** Mes del dato del índice, "2026-09" (null si es pactado). */
    @Column(name = "periodo_indice", length = 7)
    private String periodoIndice;

    @Column(name = "porcentaje", nullable = false, precision = 6, scale = 3)
    private BigDecimal porcentaje;

    @Column(name = "renta_anterior", nullable = false, precision = 8, scale = 2)
    private BigDecimal rentaAnterior;

    @Column(name = "renta_nueva", nullable = false, precision = 8, scale = 2)
    private BigDecimal rentaNueva;

    @Column(name = "fuente")
    private String fuente;

    @Column(name = "id_usuario")
    private Integer idUsuario;

    @Column(name = "fecha_confirmacion", nullable = false)
    private LocalDateTime fechaConfirmacion;
}
