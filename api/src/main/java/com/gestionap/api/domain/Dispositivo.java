package com.gestionap.api.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/** Dispositivo iOS de un usuario para notificaciones push (tabla nueva, V8). */
@Entity
@Table(name = "Dispositivos")
@Getter
@Setter
@NoArgsConstructor
public class Dispositivo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_dispositivo")
    private Integer id;

    @Column(name = "id_usuario", nullable = false)
    private Integer idUsuario;

    @Column(name = "token", nullable = false, unique = true, length = 200)
    private String token;

    @Column(name = "plataforma", nullable = false, length = 10)
    private String plataforma = "IOS";

    @Column(name = "fecha_alta", nullable = false)
    private LocalDateTime fechaAlta;
}
