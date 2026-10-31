package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/** Firma de una de las partes de un contrato (tabla nueva, V7). */
@Entity
@Table(name = "FirmasContrato")
@Getter
@Setter
@NoArgsConstructor
public class FirmaContrato {

    public enum Parte { ARRENDADOR, ARRENDATARIO }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_firma")
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_contrato", nullable = false)
    private Contrato contrato;

    @Enumerated(EnumType.STRING)
    @Column(name = "parte", nullable = false, length = 12)
    private Parte parte;

    @Column(name = "nombre", nullable = false, length = 150)
    private String nombre;

    @Column(name = "dni", length = 20)
    private String dni;

    @Column(name = "id_usuario")
    private Integer idUsuario;

    @Column(name = "imagen_ruta", nullable = false)
    private String imagenRuta;

    @Column(name = "fecha", nullable = false)
    private LocalDateTime fecha;

    @Column(name = "ip", length = 45)
    private String ip;

    /** SHA-256 de los datos del contrato que se firmó (partes, habitación, fechas y renta). */
    @Column(name = "huella_pdf", nullable = false, length = 64)
    private String huellaPdf;

    /** EN_PANTALLA hoy; el nombre del proveedor si un día se integra uno con validez reforzada. */
    @Column(name = "proveedor", nullable = false, length = 30)
    private String proveedor = "EN_PANTALLA";
}
