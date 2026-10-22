-- Esquema de gestion_alquileres_pro (MariaDB) DESPUÉS de la migración V1,
-- adaptado a H2: ENUM -> VARCHAR, sin ENGINE/CHARSET.
CREATE TABLE Usuarios (
    id_usuario    INT AUTO_INCREMENT PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    dni           VARCHAR(20),
    password_hash VARCHAR(64)  NOT NULL,
    rol           VARCHAR(20)  NOT NULL DEFAULT 'usuario',
    activo        TINYINT(1)   NOT NULL DEFAULT 1
);

CREATE TABLE Ciudades (
    id_ciudad INT AUTO_INCREMENT PRIMARY KEY,
    nombre    VARCHAR(100) NOT NULL
);

CREATE TABLE Pisos (
    id_piso             INT AUTO_INCREMENT PRIMARY KEY,
    direccion           VARCHAR(150) NOT NULL,
    numero_habitaciones INT NOT NULL,
    id_ciudad           INT NOT NULL REFERENCES Ciudades (id_ciudad),
    id_propietario      INT NOT NULL REFERENCES Usuarios (id_usuario)
);

CREATE TABLE DatosPiso (
    id                        INT AUTO_INCREMENT PRIMARY KEY,
    id_piso                   INT NOT NULL UNIQUE REFERENCES Pisos (id_piso) ON DELETE CASCADE,
    precio_compra             DECIMAL(10,2) DEFAULT 0.00,
    itp_pagado                DECIMAL(10,2) DEFAULT 0.00,
    gastos_notaria            DECIMAL(10,2) DEFAULT 0.00,
    gastos_registro           DECIMAL(10,2) DEFAULT 0.00,
    coste_reforma             DECIMAL(10,2) DEFAULT 0.00,
    coste_mobiliario          DECIMAL(10,2) DEFAULT 0.00,
    otros_gastos_compra       DECIMAL(10,2) DEFAULT 0.00,
    tiene_hipoteca            TINYINT(1)    DEFAULT 0,
    importe_hipoteca          DECIMAL(10,2) DEFAULT 0.00,
    tipo_interes              DECIMAL(5,2)  DEFAULT 0.00,
    plazo_anos                INT           DEFAULT 0,
    cuota_mensual_hipoteca    DECIMAL(10,2) DEFAULT 0.00,
    gasto_ibi_anual           DECIMAL(10,2) DEFAULT 0.00,
    gasto_comunidad_mensual   DECIMAL(10,2) DEFAULT 0.00,
    gasto_seguro_anual        DECIMAL(10,2) DEFAULT 0.00,
    gasto_mantenimiento_anual DECIMAL(10,2) DEFAULT 0.00,
    valor_mercado_actual      DECIMAL(10,2) DEFAULT 0.00,
    fecha_compra              DATE,
    notas                     TEXT
);

CREATE TABLE Habitaciones (
    id_habitacion INT AUTO_INCREMENT PRIMARY KEY,
    numero        INT NOT NULL,
    precio        DECIMAL(8,2) NOT NULL,
    estado        VARCHAR(20) NOT NULL DEFAULT 'disponible',
    id_piso       INT NOT NULL REFERENCES Pisos (id_piso)
);

CREATE TABLE Inquilinos (
    id_inquilino INT AUTO_INCREMENT PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL,
    apellidos    VARCHAR(100) NOT NULL,
    dni          VARCHAR(20)  NOT NULL UNIQUE,
    telefono     VARCHAR(20),
    email        VARCHAR(100),
    id_usuario   INT UNIQUE REFERENCES Usuarios (id_usuario) ON DELETE SET NULL
);

CREATE TABLE Contratos (
    id_contrato    INT AUTO_INCREMENT PRIMARY KEY,
    id_habitacion  INT NOT NULL REFERENCES Habitaciones (id_habitacion),
    id_inquilino   INT NOT NULL REFERENCES Inquilinos (id_inquilino),
    fecha_inicio   DATE NOT NULL,
    fecha_fin      DATE NOT NULL,
    precio_mensual DECIMAL(8,2) NOT NULL
);

CREATE TABLE Invitaciones (
    id_invitacion    INT AUTO_INCREMENT PRIMARY KEY,
    codigo_hash      CHAR(64) NOT NULL UNIQUE,
    id_inquilino     INT NOT NULL REFERENCES Inquilinos (id_inquilino) ON DELETE CASCADE,
    id_creador       INT NOT NULL REFERENCES Usuarios (id_usuario) ON DELETE CASCADE,
    fecha_creacion   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion DATETIME NOT NULL,
    fecha_uso        DATETIME
);

CREATE TABLE actividad (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario  INT,
    accion      VARCHAR(100),
    descripcion VARCHAR(255),
    fecha       DATETIME DEFAULT CURRENT_TIMESTAMP
);
