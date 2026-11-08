package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;

@Entity
@Table(name = "Habitaciones")
@Getter
@Setter
@NoArgsConstructor
public class Habitacion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_habitacion")
    private Integer id;

    @Column(name = "numero", nullable = false)
    private int numero;

    @Column(name = "precio", nullable = false, precision = 8, scale = 2)
    private BigDecimal precio;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado", nullable = false, columnDefinition = "enum('disponible','alquilada','mantenimiento')")
    private EstadoHabitacion estado = EstadoHabitacion.disponible;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_piso", nullable = false)
    private Piso piso;

    /** V12: habitación, plaza de garaje o trastero. La tabla conserva su nombre del escritorio. */
    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false, columnDefinition = "enum('habitacion','plaza','trastero')")
    private TipoUnidad tipo = TipoUnidad.habitacion;

    @Column(name = "metros", precision = 6, scale = 2)
    private BigDecimal metros;

    @Column(name = "planta", length = 20)
    private String planta;

    /** Solo en plazas de garaje. */
    @Enumerated(EnumType.STRING)
    @Column(name = "vehiculo", columnDefinition = "enum('coche','moto')")
    private Vehiculo vehiculo;

    /** "Hab. 3", "Plaza 3", "Trastero 3". */
    public String etiqueta() {
        return tipo.etiqueta(numero);
    }
}
