-- =====================================================================
-- gestionapro-api · Migración V10 (eliminar la propia cuenta, App Store)
-- Base de datos: gestion_alquileres_pro. Después de V9.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_v10.sql
--   mysql -u root gestion_alquileres_pro < V10__baja_de_cuenta.sql
--
-- Compatibilidad con el escritorio: solo AÑADE una columna que admite nulos.
-- =====================================================================

-- Fecha en que el titular eliminó su cuenta (datos personales ya anonimizados). NULL = cuenta normal.
ALTER TABLE Usuarios
    ADD COLUMN fecha_baja DATETIME NULL
        COMMENT 'Cuenta eliminada por su titular: datos personales anonimizados; se conservan contratos y pagos';
