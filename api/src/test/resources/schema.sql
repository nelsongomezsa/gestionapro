-- Esquema de gestion_alquileres_pro (MariaDB) DESPUÉS de las migraciones V1 y V2,
-- adaptado a H2: ENUM -> VARCHAR, sin ENGINE/CHARSET.
CREATE TABLE Usuarios (
    id_usuario    INT AUTO_INCREMENT PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    dni           VARCHAR(20),
    iban          VARCHAR(34),
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
    id_usuario   INT UNIQUE REFERENCES Usuarios (id_usuario) ON DELETE SET NULL,
    id_propietario INT REFERENCES Usuarios (id_usuario) ON DELETE SET NULL
);

CREATE TABLE Contratos (
    id_contrato    INT AUTO_INCREMENT PRIMARY KEY,
    id_habitacion  INT NOT NULL REFERENCES Habitaciones (id_habitacion),
    id_inquilino   INT NOT NULL REFERENCES Inquilinos (id_inquilino),
    fecha_inicio   DATE NOT NULL,
    fecha_fin      DATE NOT NULL,
    precio_mensual DECIMAL(8,2) NOT NULL
);

CREATE TABLE Pagos (
    id_pago     INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato INT NOT NULL REFERENCES Contratos (id_contrato),
    cantidad    DECIMAL(8,2) NOT NULL,
    metodo_pago VARCHAR(20) NOT NULL DEFAULT 'transferencia',
    fecha_pago  DATE NOT NULL
);

CREATE TABLE Incidencias (
    id_incidencia    INT AUTO_INCREMENT PRIMARY KEY,
    id_habitacion    INT NOT NULL REFERENCES Habitaciones (id_habitacion),
    id_inquilino     INT NOT NULL REFERENCES Inquilinos (id_inquilino),
    descripcion      VARCHAR(255) NOT NULL,
    estado           VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    fecha            DATE NOT NULL,
    coste_reparacion DECIMAL(8,2) DEFAULT 0.00
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

CREATE TABLE Notificaciones (
    id_notificacion INT AUTO_INCREMENT PRIMARY KEY,
    tipo            VARCHAR(50)  NOT NULL,
    titulo          VARCHAR(200) NOT NULL,
    descripcion     TEXT,
    referencia      VARCHAR(100),
    fecha           DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    leida           TINYINT(1)   NOT NULL DEFAULT 0,
    id_usuario      INT          NOT NULL REFERENCES Usuarios (id_usuario) ON DELETE CASCADE
);

CREATE TABLE actividad (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario  INT,
    accion      VARCHAR(100),
    descripcion VARCHAR(255),
    fecha       DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- V3: recibos numerados por propietario y año.
CREATE TABLE Recibos (
    id_recibo      INT AUTO_INCREMENT PRIMARY KEY,
    id_pago        INT NOT NULL UNIQUE REFERENCES Pagos (id_pago) ON DELETE CASCADE,
    id_propietario INT NOT NULL REFERENCES Usuarios (id_usuario),
    anio           INT NOT NULL,
    numero         INT NOT NULL,
    fecha_emision  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_recibos_numero UNIQUE (id_propietario, anio, numero)
);

-- V4: fianzas por contrato.
CREATE TABLE Fianzas (
    id_fianza           INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato         INT NOT NULL UNIQUE REFERENCES Contratos (id_contrato) ON DELETE CASCADE,
    importe             DECIMAL(8,2) NOT NULL,
    fecha_cobro         DATE,
    fecha_deposito      DATE,
    organismo_deposito  VARCHAR(150),
    referencia_deposito VARCHAR(100),
    fecha_devolucion    DATE,
    importe_devuelto    DECIMAL(8,2),
    motivo_retencion    VARCHAR(255),
    notas               TEXT
);

-- V5: historial de actualizaciones de renta.
CREATE TABLE ActualizacionesRenta (
    id_actualizacion   INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato        INT NOT NULL REFERENCES Contratos (id_contrato) ON DELETE CASCADE,
    fecha_efecto       DATE NOT NULL,
    indice             VARCHAR(10) NOT NULL,
    periodo_indice     VARCHAR(7),
    porcentaje         DECIMAL(6,3) NOT NULL,
    renta_anterior     DECIMAL(8,2) NOT NULL,
    renta_nueva        DECIMAL(8,2) NOT NULL,
    fuente             VARCHAR(255),
    id_usuario         INT REFERENCES Usuarios (id_usuario) ON DELETE SET NULL,
    fecha_confirmacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_actualizacion_contrato_fecha UNIQUE (id_contrato, fecha_efecto)
);

-- V6: gastos, fotos de incidencias e inventarios.
CREATE TABLE Gastos (
    id_gasto       INT AUTO_INCREMENT PRIMARY KEY,
    id_piso        INT NOT NULL REFERENCES Pisos (id_piso) ON DELETE CASCADE,
    id_habitacion  INT REFERENCES Habitaciones (id_habitacion) ON DELETE SET NULL,
    id_incidencia  INT UNIQUE REFERENCES Incidencias (id_incidencia) ON DELETE SET NULL,
    categoria      VARCHAR(20) NOT NULL,
    concepto       VARCHAR(200) NOT NULL,
    importe        DECIMAL(10,2) NOT NULL,
    fecha          DATE NOT NULL,
    deducible      TINYINT(1) NOT NULL DEFAULT 1,
    factura_ruta   VARCHAR(255),
    factura_tipo   VARCHAR(50),
    fecha_alta     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE FotosIncidencia (
    id_foto        INT AUTO_INCREMENT PRIMARY KEY,
    id_incidencia  INT NOT NULL REFERENCES Incidencias (id_incidencia) ON DELETE CASCADE,
    ruta           VARCHAR(255) NOT NULL,
    tipo           VARCHAR(50) NOT NULL,
    id_usuario     INT REFERENCES Usuarios (id_usuario) ON DELETE SET NULL,
    fecha          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Inventarios (
    id_inventario  INT AUTO_INCREMENT PRIMARY KEY,
    id_habitacion  INT NOT NULL REFERENCES Habitaciones (id_habitacion) ON DELETE CASCADE,
    id_contrato    INT REFERENCES Contratos (id_contrato) ON DELETE SET NULL,
    tipo           VARCHAR(10) NOT NULL,
    fecha          DATE NOT NULL,
    observaciones  TEXT,
    fecha_alta     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ElementosInventario (
    id_elemento    INT AUTO_INCREMENT PRIMARY KEY,
    id_inventario  INT NOT NULL REFERENCES Inventarios (id_inventario) ON DELETE CASCADE,
    nombre         VARCHAR(100) NOT NULL,
    estado         VARCHAR(10) NOT NULL,
    observaciones  VARCHAR(255),
    foto_ruta      VARCHAR(255),
    foto_tipo      VARCHAR(50),
    orden          INT NOT NULL DEFAULT 0
);

-- V7: mensajes y firmas de contratos.
CREATE TABLE Mensajes (
    id_mensaje     INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato    INT NOT NULL REFERENCES Contratos (id_contrato) ON DELETE CASCADE,
    id_incidencia  INT REFERENCES Incidencias (id_incidencia) ON DELETE SET NULL,
    id_autor       INT REFERENCES Usuarios (id_usuario) ON DELETE SET NULL,
    texto          TEXT NOT NULL,
    fecha          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    leido          TINYINT(1) NOT NULL DEFAULT 0
);

CREATE TABLE FirmasContrato (
    id_firma       INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato    INT NOT NULL REFERENCES Contratos (id_contrato) ON DELETE CASCADE,
    parte          VARCHAR(12) NOT NULL,
    nombre         VARCHAR(150) NOT NULL,
    dni            VARCHAR(20),
    id_usuario     INT REFERENCES Usuarios (id_usuario) ON DELETE SET NULL,
    imagen_ruta    VARCHAR(255) NOT NULL,
    fecha          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip             VARCHAR(45),
    huella_pdf     VARCHAR(64) NOT NULL,
    proveedor      VARCHAR(30) NOT NULL DEFAULT 'EN_PANTALLA',
    CONSTRAINT uk_firma_contrato_parte UNIQUE (id_contrato, parte)
);
