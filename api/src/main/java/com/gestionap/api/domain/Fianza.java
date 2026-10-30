package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Fianza de un contrato: cobro, depósito en el organismo autonómico y devolución (tabla nueva, V4). */
@Entity
@Table(name = "Fianzas")
@Getter
@Setter
@NoArgsConstructor
public class Fianza {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_fianza")
    private Integer id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_contrato", nullable = false, unique = true)
    private Contrato contrato;

    @Column(name = "importe", nullable = false, precision = 8, scale = 2)
    private BigDecimal importe;

    @Column(name = "fecha_cobro")
    private LocalDate fechaCobro;

    @Column(name = "fecha_deposito")
    private LocalDate fechaDeposito;

    @Column(name = "organismo_deposito", length = 150)
    private String organismoDeposito;

    @Column(name = "referencia_deposito", length = 100)
    private String referenciaDeposito;

    @Column(name = "fecha_devolucion")
    private LocalDate fechaDevolucion;

    @Column(name = "importe_devuelto", precision = 8, scale = 2)
    private BigDecimal importeDevuelto;

    @Column(name = "motivo_retencion")
    private String motivoRetencion;

    @Column(name = "notas", columnDefinition = "TEXT")
    private String notas;

    public boolean devuelta() {
        return fechaDevolucion != null;
    }
}
