-- =====================================================================
-- gestionapro-api · Migración V2 (fase 4B: habitaciones e inquilinos)
-- Base de datos: gestion_alquileres_pro.   SE APLICA A MANO, después de V1.
--
-- La API arranca con ddl-auto=validate: tras actualizar la API a la fase 4B no
-- arrancará hasta aplicar esta migración.
--
--   mysqldump -u root gestion_alquileres_pro > backup_antes_v2.sql
--   mysql -u root gestion_alquileres_pro < V2__inquilinos_propietario_iban.sql
--
-- Compatibilidad con el escritorio (comprobado en su código): solo AÑADE columnas
-- que admiten NULL. InquilinoDAO y UsuarioDAO listan columnas explícitas en sus
-- SELECT/INSERT, así que no les afectan. Un inquilino creado desde el escritorio
-- quedará con id_propietario NULL hasta que tenga un contrato (ver abajo).
-- =====================================================================

-- 1) Propietario de cada inquilino.
-- Antes un inquilino no pertenecía a nadie: un propietario solo "veía" a los que tenían
-- contrato en sus pisos, así que uno recién dado de alta (aún sin contrato) no lo veía
-- nadie salvo el admin. La API muestra a un propietario los inquilinos que creó él
-- (id_propietario) MÁS los que tienen contrato en sus pisos.
ALTER TABLE Inquilinos
    ADD COLUMN id_propietario INT NULL,
    ADD CONSTRAINT fk_inquilinos_propietario
        FOREIGN KEY (id_propietario) REFERENCES Usuarios (id_usuario) ON DELETE SET NULL,
    ADD INDEX idx_inquilinos_propietario (id_propietario);

-- Relleno: el propietario del piso de su contrato más reciente. Comprobado sobre los
-- datos actuales: los 25 inquilinos tienen contrato y ninguno en pisos de dos
-- propietarios distintos, así que la asignación no es ambigua.
UPDATE Inquilinos i
SET i.id_propietario = (
    SELECT p.id_propietario
    FROM Contratos c
    JOIN Habitaciones h ON h.id_habitacion = c.id_habitacion
    JOIN Pisos p        ON p.id_piso       = h.id_piso
    WHERE c.id_inquilino = i.id_inquilino
    ORDER BY c.fecha_inicio DESC
    LIMIT 1)
WHERE i.id_propietario IS NULL;

-- 2) IBAN del propietario, para el QR de pago SEPA.
-- El escritorio generaba el QR con un IBAN de relleno (ES00 0000...) y "GestionAp" como
-- beneficiario, así que no servía para cobrar. La API usa el IBAN y el nombre del
-- propietario del piso; si no tiene IBAN, avisa en vez de generar un QR inútil.
ALTER TABLE Usuarios
    ADD COLUMN iban VARCHAR(34) NULL AFTER dni;

-- Comprobación: inquilinos sin propietario tras el relleno (debe ser 0 con los datos actuales).
SELECT COUNT(*) AS inquilinos_sin_propietario FROM Inquilinos WHERE id_propietario IS NULL;
