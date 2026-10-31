-- =====================================================================
-- gestionapro-api · Migración V7 (fase 6: mensajería y firma de contratos)
-- Base de datos: gestion_alquileres_pro. Después de V6.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_v7.sql
--   mysql -u root gestion_alquileres_pro < V7__mensajes_y_firmas.sql
--
-- Compatibilidad con el escritorio: solo CREA tablas nuevas. Si el escritorio borra un
-- contrato, sus mensajes y firmas se borran con él.
-- =====================================================================

-- Mensajes entre propietario e inquilino, siempre ligados a un contrato y, si se quiere,
-- a una incidencia de ese contrato.
CREATE TABLE Mensajes (
    id_mensaje     INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato    INT NOT NULL,
    id_incidencia  INT NULL,
    id_autor       INT NULL,
    texto          TEXT NOT NULL,
    fecha          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    leido          TINYINT(1) NOT NULL DEFAULT 0,
    CONSTRAINT fk_mensajes_contrato FOREIGN KEY (id_contrato) REFERENCES Contratos (id_contrato) ON DELETE CASCADE,
    CONSTRAINT fk_mensajes_incidencia FOREIGN KEY (id_incidencia) REFERENCES Incidencias (id_incidencia) ON DELETE SET NULL,
    CONSTRAINT fk_mensajes_autor FOREIGN KEY (id_autor) REFERENCES Usuarios (id_usuario) ON DELETE SET NULL,
    INDEX idx_mensajes_contrato_fecha (id_contrato, fecha)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_spanish_ci;

-- Firma en pantalla de un contrato (firma electrónica simple): una por parte. Se guarda la
-- imagen de la firma, quién firmó, cuándo, desde qué IP y la huella SHA-256 de los datos del
-- contrato firmado (partes, habitación, fechas y renta), para saber si cambió después.
CREATE TABLE FirmasContrato (
    id_firma       INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato    INT NOT NULL,
    parte          VARCHAR(12) NOT NULL,
    nombre         VARCHAR(150) NOT NULL,
    dni            VARCHAR(20) NULL,
    id_usuario     INT NULL,
    imagen_ruta    VARCHAR(255) NOT NULL,
    fecha          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip             VARCHAR(45) NULL,
    huella_pdf     VARCHAR(64) NOT NULL,
    proveedor      VARCHAR(30) NOT NULL DEFAULT 'EN_PANTALLA',
    CONSTRAINT uk_firma_contrato_parte UNIQUE (id_contrato, parte),
    CONSTRAINT fk_firmas_contrato FOREIGN KEY (id_contrato) REFERENCES Contratos (id_contrato) ON DELETE CASCADE,
    CONSTRAINT fk_firmas_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios (id_usuario) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_spanish_ci;
