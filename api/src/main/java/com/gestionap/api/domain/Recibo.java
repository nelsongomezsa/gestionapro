package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/** Recibo de un pago, numerado por propietario y año (tabla nueva de la API, V3). */
@Entity
@Table(name = "Recibos")
@Getter
@Setter
@NoArgsConstructor
public class Recibo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_recibo")
    private Integer id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_pago", nullable = false, unique = true)
    private Pago pago;

    @Column(name = "id_propietario", nullable = false)
    private Integer idPropietario;

    @Column(name = "anio", nullable = false)
    private Integer anio;

    @Column(name = "numero", nullable = false)
    private Integer numero;

    @Column(name = "fecha_emision", nullable = false)
    private LocalDateTime fechaEmision;

    /** 2026-0007 */
    public String codigo() {
        return codigo(anio, numero);
    }

    public static String codigo(int anio, int numero) {
        return "%d-%04d".formatted(anio, numero);
    }
}
