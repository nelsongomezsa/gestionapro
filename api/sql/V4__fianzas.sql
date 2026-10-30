-- =====================================================================
-- gestionapro-api · Migración V4 (fase 5: fianzas por contrato)
-- Base de datos: gestion_alquileres_pro. Después de V3.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_v4.sql
--   mysql -u root gestion_alquileres_pro < V4__fianzas.sql
--
-- Compatibilidad con el escritorio: solo CREA una tabla nueva. Si el escritorio borra
-- un contrato, su fianza se borra con él (ON DELETE CASCADE).
-- =====================================================================

-- Una fianza por contrato: cuándo la entregó el inquilino, dónde se depositó
-- (el organismo de la comunidad autónoma, texto libre) y su devolución.
CREATE TABLE Fianzas (
    id_fianza           INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato         INT NOT NULL,
    importe             DECIMAL(8,2) NOT NULL,
    fecha_cobro         DATE NULL,
    fecha_deposito      DATE NULL,
    organismo_deposito  VARCHAR(150) NULL,
    referencia_deposito VARCHAR(100) NULL,
    fecha_devolucion    DATE NULL,
    importe_devuelto    DECIMAL(8,2) NULL,
    motivo_retencion    VARCHAR(255) NULL,
    notas               TEXT NULL,
    CONSTRAINT uk_fianzas_contrato UNIQUE (id_contrato),
    CONSTRAINT fk_fianzas_contrato FOREIGN KEY (id_contrato) REFERENCES Contratos (id_contrato) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_spanish_ci;
