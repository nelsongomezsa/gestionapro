-- =====================================================================
-- gestionapro-api · Migración V5 (fase 5: actualización anual de la renta)
-- Base de datos: gestion_alquileres_pro. Después de V4.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_v5.sql
--   mysql -u root gestion_alquileres_pro < V5__actualizaciones_renta.sql
--
-- Compatibilidad con el escritorio: solo CREA una tabla nueva. Al confirmar una
-- actualización la API cambia Contratos.precio_mensual, el mismo campo que edita el
-- escritorio, así que el escritorio ve la renta nueva sin cambios.
-- =====================================================================

-- Historial de actualizaciones: índice aplicado (IRAV o IPC del INE, o un porcentaje
-- pactado), el mes del dato, el porcentaje, la renta antes y después y quién la confirmó.
CREATE TABLE ActualizacionesRenta (
    id_actualizacion INT AUTO_INCREMENT PRIMARY KEY,
    id_contrato      INT NOT NULL,
    fecha_efecto     DATE NOT NULL,
    indice           VARCHAR(10) NOT NULL,
    periodo_indice   VARCHAR(7) NULL,
    porcentaje       DECIMAL(6,3) NOT NULL,
    renta_anterior   DECIMAL(8,2) NOT NULL,
    renta_nueva      DECIMAL(8,2) NOT NULL,
    fuente           VARCHAR(255) NULL,
    id_usuario       INT NULL,
    fecha_confirmacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_actualizacion_contrato_fecha UNIQUE (id_contrato, fecha_efecto),
    CONSTRAINT fk_actualizacion_contrato FOREIGN KEY (id_contrato) REFERENCES Contratos (id_contrato) ON DELETE CASCADE,
    CONSTRAINT fk_actualizacion_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios (id_usuario) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_spanish_ci;
