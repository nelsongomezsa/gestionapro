-- =====================================================================
-- gestionapro-api · Migración V6 (fase 5: gastos reales, fotos e inventarios)
-- Base de datos: gestion_alquileres_pro. Después de V5.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_v6.sql
--   mysql -u root gestion_alquileres_pro < V6__gastos_y_fotos.sql
--
-- Compatibilidad con el escritorio: solo CREA tablas nuevas. Los archivos (facturas y
-- fotos) no van en la base: se guardan en disco (gestionap.archivos.dir) y aquí solo su
-- ruta relativa. Si el escritorio borra un piso, una incidencia o una habitación, lo
-- suyo se borra en cascada o queda sin enlazar, sin errores.
-- =====================================================================

-- Gastos reales por piso (y opcionalmente por habitación). Los de una incidencia resuelta
-- con coste se crean solos (id_incidencia).
CREATE TABLE Gastos (
    id_gasto       INT AUTO_INCREMENT PRIMARY KEY,
    id_piso        INT NOT NULL,
    id_habitacion  INT NULL,
    id_incidencia  INT NULL,
    categoria      VARCHAR(20) NOT NULL,
    concepto       VARCHAR(200) NOT NULL,
    importe        DECIMAL(10,2) NOT NULL,
    fecha          DATE NOT NULL,
    deducible      TINYINT(1) NOT NULL DEFAULT 1,
    factura_ruta   VARCHAR(255) NULL,
    factura_tipo   VARCHAR(50) NULL,
    fecha_alta     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_gastos_incidencia UNIQUE (id_incidencia),
    CONSTRAINT fk_gastos_piso FOREIGN KEY (id_piso) REFERENCES Pisos (id_piso) ON DELETE CASCADE,
    CONSTRAINT fk_gastos_habitacion FOREIGN KEY (id_habitacion) REFERENCES Habitaciones (id_habitacion) ON DELETE SET NULL,
    CONSTRAINT fk_gastos_incidencia FOREIGN KEY (id_incidencia) REFERENCES Incidencias (id_incidencia) ON DELETE SET NULL,
    INDEX idx_gastos_piso_fecha (id_piso, fecha)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_spanish_ci;

-- Fotos de una incidencia.
CREATE TABLE FotosIncidencia (
    id_foto        INT AUTO_INCREMENT PRIMARY KEY,
    id_incidencia  INT NOT NULL,
    ruta           VARCHAR(255) NOT NULL,
    tipo           VARCHAR(50) NOT NULL,
    id_usuario     INT NULL,
    fecha          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fotos_incidencia FOREIGN KEY (id_incidencia) REFERENCES Incidencias (id_incidencia) ON DELETE CASCADE,
    CONSTRAINT fk_fotos_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios (id_usuario) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_spanish_ci;

-- Inventario de entrada o salida de una habitación (opcionalmente ligado a un contrato).
CREATE TABLE Inventarios (
    id_inventario  INT AUTO_INCREMENT PRIMARY KEY,
    id_habitacion  INT NOT NULL,
    id_contrato    INT NULL,
    tipo           VARCHAR(10) NOT NULL,
    fecha          DATE NOT NULL,
    observaciones  TEXT NULL,
    fecha_alta     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_inventarios_habitacion FOREIGN KEY (id_habitacion) REFERENCES Habitaciones (id_habitacion) ON DELETE CASCADE,
    CONSTRAINT fk_inventarios_contrato FOREIGN KEY (id_contrato) REFERENCES Contratos (id_contrato) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_spanish_ci;

-- Elementos de un inventario: qué hay, en qué estado y, si se quiere, una foto.
CREATE TABLE ElementosInventario (
    id_elemento    INT AUTO_INCREMENT PRIMARY KEY,
    id_inventario  INT NOT NULL,
    nombre         VARCHAR(100) NOT NULL,
    estado         VARCHAR(10) NOT NULL,
    observaciones  VARCHAR(255) NULL,
    foto_ruta      VARCHAR(255) NULL,
    foto_tipo      VARCHAR(50) NULL,
    orden          INT NOT NULL DEFAULT 0,
    CONSTRAINT fk_elementos_inventario FOREIGN KEY (id_inventario) REFERENCES Inventarios (id_inventario) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_spanish_ci;
