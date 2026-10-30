-- =====================================================================
-- gestionapro-api · Migración V3 (fase 5: recibos de pago numerados)
-- Base de datos: gestion_alquileres_pro. Después de V1 y V2.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_v3.sql
--   mysql -u root gestion_alquileres_pro < V3__recibos.sql
--
-- Compatibilidad con el escritorio: solo CREA una tabla nueva; no toca Pagos ni
-- ninguna tabla que use el escritorio. Si el escritorio borra un pago, su recibo
-- se borra con él (ON DELETE CASCADE) y el borrado no falla.
-- =====================================================================

-- Numeración por propietario y año: 2026-0001, 2026-0002... sin huecos ni repetidos.
-- Un pago registrado desde el escritorio recibe su número la primera vez que se pide
-- su recibo.
CREATE TABLE Recibos (
    id_recibo      INT AUTO_INCREMENT PRIMARY KEY,
    id_pago        INT NOT NULL,
    id_propietario INT NOT NULL,
    anio           INT NOT NULL,
    numero         INT NOT NULL,
    fecha_emision  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_recibos_pago UNIQUE (id_pago),
    CONSTRAINT uk_recibos_numero UNIQUE (id_propietario, anio, numero),
    CONSTRAINT fk_recibos_pago FOREIGN KEY (id_pago) REFERENCES Pagos (id_pago) ON DELETE CASCADE,
    CONSTRAINT fk_recibos_propietario FOREIGN KEY (id_propietario) REFERENCES Usuarios (id_usuario)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_spanish_ci;
