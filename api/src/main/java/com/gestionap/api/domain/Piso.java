package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "Pisos")
@Getter
@Setter
@NoArgsConstructor
public class Piso {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_piso")
    private Integer id;

    @Column(name = "direccion", nullable = false, length = 150)
    private String direccion;

    @Column(name = "numero_habitaciones", nullable = false)
    private int numeroHabitaciones;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_ciudad", nullable = false)
    private Ciudad ciudad;

    /** V12: vivienda (habitaciones), garajes o trasteros. */
    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false, columnDefinition = "enum('vivienda','garajes','trasteros')")
    private TipoInmueble tipo = TipoInmueble.vivienda;

    /** Añadido en la migración V1. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_propietario", nullable = false)
    private Usuario propietario;

    /** Datos de compra/hipoteca/gastos (tabla DatosPiso, 1:1, opcional). */
    @OneToOne(mappedBy = "piso", cascade = CascadeType.ALL, orphanRemoval = true, fetch = FetchType.LAZY)
    private DatosPiso datosFinancieros;

    public void setDatosFinancieros(DatosPiso datos) {
        this.datosFinancieros = datos;
        if (datos != null) datos.setPiso(this);
    }
}
