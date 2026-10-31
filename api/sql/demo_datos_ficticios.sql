-- =====================================================================
-- gestionapro-api · Datos de demo claramente ficticios (no es una migración de esquema)
-- Base de datos: gestion_alquileres_pro (solo datos inventados).
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_datos_ficticios.sql
--   mysql -u root gestion_alquileres_pro < demo_datos_ficticios.sql
--
-- Los inquilinos de demo tenían DNI, emails y teléfonos con formato real (gmail, hotmail…).
-- Se sustituyen por valores que no pueden ser de nadie, sin cambiar su estructura:
--  - DNI: 00000001R, 00000002W… (8 cifras y la letra de control correcta, para que cualquier
--    validación del escritorio los siga aceptando).
--  - Email: nombre.apellido@example.com (dominio reservado para ejemplos, RFC 2606).
--  - Teléfono: 600 000 0NN.
-- Idempotente: volver a ejecutarlo deja los mismos valores.
-- =====================================================================

UPDATE Inquilinos
SET dni = CONCAT(LPAD(id_inquilino, 8, '0'), SUBSTRING('TRWAGMYFPDXBNJZSQVHLCKE', MOD(id_inquilino, 23) + 1, 1)),
    telefono = CONCAT('600 000 ', LPAD(id_inquilino, 3, '0')),
    email = CASE
        WHEN email IS NULL OR email = '' THEN email
        WHEN email LIKE '%@example.com' THEN email
        ELSE CONCAT(SUBSTRING_INDEX(email, '@', 1), '@example.com')
    END;
