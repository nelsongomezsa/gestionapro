package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/** Gasto real de un piso (o de una habitación). Tabla nueva, V6. */
@Entity
@Table(name = "Gastos")
@Getter
@Setter
@NoArgsConstructor
public class Gasto {

    /** Categorías con su tratamiento en el IRPF (orientativo) en ResumenFiscalService. */
    public enum Categoria { COMUNIDAD, IBI, SEGURO, SUMINISTROS, REPARACION, MANTENIMIENTO, MOBILIARIO, INTERESES, GESTION, OTROS }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_gasto")
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_piso", nullable = false)
    private Piso piso;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_habitacion")
    private Habitacion habitacion;

    @Column(name = "id_incidencia", unique = true)
    private Integer idIncidencia;

    @Enumerated(EnumType.STRING)
    @Column(name = "categoria", nullable = false, length = 20)
    private Categoria categoria;

    @Column(name = "concepto", nullable = false, length = 200)
    private String concepto;

    @Column(name = "importe", nullable = false, precision = 10, scale = 2)
    private BigDecimal importe;

    @Column(name = "fecha", nullable = false)
    private LocalDate fecha;

    @Column(name = "deducible", nullable = false)
    private boolean deducible = true;

    @Column(name = "factura_ruta")
    private String facturaRuta;

    @Column(name = "factura_tipo", length = 50)
    private String facturaTipo;

    @Column(name = "fecha_alta", nullable = false)
    private LocalDateTime fechaAlta;

    @PrePersist
    void alCrear() {
        if (fechaAlta == null) fechaAlta = LocalDateTime.now();
    }
}
