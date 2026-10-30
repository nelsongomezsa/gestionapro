package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Table(name = "Pagos")
@Getter
@Setter
@NoArgsConstructor
public class Pago {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_pago")
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_contrato", nullable = false)
    private Contrato contrato;

    @Column(name = "cantidad", nullable = false, precision = 8, scale = 2)
    private BigDecimal cantidad;

    @Enumerated(EnumType.STRING)
    @Column(name = "metodo_pago", nullable = false, columnDefinition = "enum('transferencia','efectivo','domiciliacion')")
    private MetodoPago metodoPago = MetodoPago.transferencia;

    @Column(name = "fecha_pago", nullable = false)
    private LocalDate fechaPago;
}
