-- =====================================================================
-- gestionapro-api · Migración V9 (seguridad: contraseñas SHA-256 antiguas)
-- Base de datos: gestion_alquileres_pro. Después de V8.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_v9.sql
--   mysql -u root gestion_alquileres_pro < V9__password_obligatorio.sql
--
-- Compatibilidad con el escritorio: solo AÑADE una columna con valor por defecto.
-- =====================================================================

-- 1 = el usuario debe cambiar su contraseña antes de seguir usando la app.
ALTER TABLE Usuarios
    ADD COLUMN debe_cambiar_password TINYINT(1) NOT NULL DEFAULT 0
        COMMENT '1: contraseña antigua (SHA-256 sin sal); la API solo deja cambiarla';

-- Las que siguen en SHA-256 (no empiezan por $2, BCrypt) quedan marcadas.
UPDATE Usuarios SET debe_cambiar_password = 1 WHERE password_hash NOT LIKE '$2%';
