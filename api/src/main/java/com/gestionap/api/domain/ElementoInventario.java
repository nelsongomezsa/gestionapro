package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Un elemento del inventario (cama, armario, pared…), su estado y, si se quiere, una foto. */
@Entity
@Table(name = "ElementosInventario")
@Getter
@Setter
@NoArgsConstructor
public class ElementoInventario {

    public enum Estado { NUEVO, BUENO, USADO, DANADO }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_elemento")
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_inventario", nullable = false)
    private Inventario inventario;

    @Column(name = "nombre", nullable = false, length = 100)
    private String nombre;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado", nullable = false, length = 10)
    private Estado estado;

    @Column(name = "observaciones")
    private String observaciones;

    @Column(name = "foto_ruta")
    private String fotoRuta;

    @Column(name = "foto_tipo", length = 50)
    private String fotoTipo;

    @Column(name = "orden", nullable = false)
    private int orden;
}
