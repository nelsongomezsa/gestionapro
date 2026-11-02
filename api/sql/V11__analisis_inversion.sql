-- =====================================================================
-- gestionapro-api · Migración V11 (análisis de inversión guardados)
-- Base de datos: gestion_alquileres_pro. Después de V10.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_v11.sql
--   mysql -u root gestion_alquileres_pro < V11__analisis_inversion.sql
--
-- Compatibilidad con el escritorio: solo CREA una tabla nueva.
-- =====================================================================

-- Simulaciones de la calculadora guardadas con nombre por cada usuario, para compararlas.
-- `datos` es la entrada de la calculadora en JSON (validada por la API); el resultado se recalcula al leer.
CREATE TABLE AnalisisInversion (
    id_analisis         INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario          INT NOT NULL,
    id_piso             INT NULL COMMENT 'Piso del que salen los datos (botón Simular); NULL si es un piso nuevo',
    nombre              VARCHAR(80) NOT NULL,
    datos               VARCHAR(2000) NOT NULL,
    fecha_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_analisis_usuario (id_usuario),
    CONSTRAINT fk_analisis_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_analisis_piso FOREIGN KEY (id_piso) REFERENCES Pisos (id_piso) ON DELETE SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_spanish_ci;
