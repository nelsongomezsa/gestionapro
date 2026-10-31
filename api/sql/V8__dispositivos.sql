-- =====================================================================
-- gestionapro-api · Migración V8 (fase 8.2: notificaciones push)
-- Base de datos: gestion_alquileres_pro. Después de V7.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_v8.sql
--   mysql -u root gestion_alquileres_pro < V8__dispositivos.sql
--
-- Compatibilidad con el escritorio: solo CREA una tabla nueva.
-- =====================================================================

-- Dispositivos iOS de cada usuario para enviarles notificaciones push (token de APNs).
CREATE TABLE Dispositivos (
    id_dispositivo INT AUTO_INCREMENT PRIMARY KEY,
    id_usuario     INT NOT NULL,
    token          VARCHAR(200) NOT NULL,
    plataforma     VARCHAR(10) NOT NULL DEFAULT 'IOS',
    fecha_alta     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_dispositivos_token UNIQUE (token),
    CONSTRAINT fk_dispositivos_usuario FOREIGN KEY (id_usuario) REFERENCES Usuarios (id_usuario) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_spanish_ci;
