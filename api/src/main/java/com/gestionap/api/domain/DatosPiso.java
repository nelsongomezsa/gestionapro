package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Tabla DatosPiso del escritorio: los datos financieros de un piso. */
@Entity
@Table(name = "DatosPiso")
@Getter
@Setter
@NoArgsConstructor
public class DatosPiso {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Integer id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_piso", nullable = false, unique = true)
    private Piso piso;

    @Column(name = "precio_compra", precision = 10, scale = 2)
    private BigDecimal precioCompra = BigDecimal.ZERO;

    @Column(name = "itp_pagado", precision = 10, scale = 2)
    private BigDecimal itpPagado = BigDecimal.ZERO;

    @Column(name = "gastos_notaria", precision = 10, scale = 2)
    private BigDecimal gastosNotaria = BigDecimal.ZERO;

    @Column(name = "gastos_registro", precision = 10, scale = 2)
    private BigDecimal gastosRegistro = BigDecimal.ZERO;

    @Column(name = "coste_reforma", precision = 10, scale = 2)
    private BigDecimal costeReforma = BigDecimal.ZERO;

    @Column(name = "coste_mobiliario", precision = 10, scale = 2)
    private BigDecimal costeMobiliario = BigDecimal.ZERO;

    @Column(name = "otros_gastos_compra", precision = 10, scale = 2)
    private BigDecimal otrosGastosCompra = BigDecimal.ZERO;

    @Column(name = "tiene_hipoteca")
    private boolean tieneHipoteca;

    @Column(name = "importe_hipoteca", precision = 10, scale = 2)
    private BigDecimal importeHipoteca = BigDecimal.ZERO;

    @Column(name = "tipo_interes", precision = 5, scale = 2)
    private BigDecimal tipoInteres = BigDecimal.ZERO;

    @Column(name = "plazo_anos")
    private Integer plazoAnos = 0;

    /** Se guarda calculada, igual que hace el escritorio al guardar. */
    @Column(name = "cuota_mensual_hipoteca", precision = 10, scale = 2)
    private BigDecimal cuotaMensualHipoteca = BigDecimal.ZERO;

    @Column(name = "gasto_ibi_anual", precision = 10, scale = 2)
    private BigDecimal gastoIbiAnual = BigDecimal.ZERO;

    @Column(name = "gasto_comunidad_mensual", precision = 10, scale = 2)
    private BigDecimal gastoComunidadMensual = BigDecimal.ZERO;

    @Column(name = "gasto_seguro_anual", precision = 10, scale = 2)
    private BigDecimal gastoSeguroAnual = BigDecimal.ZERO;

    @Column(name = "gasto_mantenimiento_anual", precision = 10, scale = 2)
    private BigDecimal gastoMantenimientoAnual = BigDecimal.ZERO;

    @Column(name = "valor_mercado_actual", precision = 10, scale = 2)
    private BigDecimal valorMercadoActual = BigDecimal.ZERO;

    @Column(name = "fecha_compra")
    private LocalDate fechaCompra;

    @Column(name = "notas", columnDefinition = "text")
    private String notas;
}
