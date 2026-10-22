-- =====================================================================
-- gestionapro-api · Migración V1
-- Base de datos: gestion_alquileres_pro (MariaDB 10.4, compartida con la
-- app de escritorio GestionAp).
--
-- SE APLICA A MANO. La API arranca con ddl-auto=validate y NO arrancará
-- hasta que esta migración esté aplicada (valida estas columnas/tablas).
--
-- ORDEN OBLIGATORIO:
--   1. Aplicar en la app de escritorio el parche
--      api/patches/escritorio-rol-inquilino.patch y desplegar esa versión.
--      Sin él, en cuanto exista un usuario con rol 'inquilino', la pantalla
--      de Gestión de usuarios del escritorio deja de cargar
--      (Rol.valueOf("inquilino") lanza IllegalArgumentException).
--   2. Hacer copia:  mysqldump -u root gestion_alquileres_pro > backup.sql
--   3. Aplicar este script.
--
-- Compatibilidad con el escritorio (comprobado en su código):
--   - Solo AÑADE columnas/tablas y un valor al ENUM; no renombra nada.
--     'admin' y 'usuario' siguen igual (la API mapea usuario -> PROPIETARIO).
--   - Todos los SELECT/INSERT del escritorio listan columnas explícitas, así
--     que las columnas nuevas no les afectan.
--   - El escritorio nunca inserta en Pisos (PisoDAO solo lista), por eso
--     Pisos.id_propietario puede ser NOT NULL.
--   - El escritorio sí borra Inquilinos: las invitaciones se borran en
--     cascada y Inquilinos.id_usuario no impide borrar usuarios (SET NULL).
-- =====================================================================

-- 1) Rol de inquilino (cuentas creadas desde la app iOS con invitación).
ALTER TABLE Usuarios
    MODIFY rol ENUM('admin','usuario','inquilino') NOT NULL DEFAULT 'usuario';

-- La columna ya guarda BCrypt (60 caracteres) desde hace tiempo; el comentario
-- "SHA-256 hex lowercase" estaba desactualizado. Solo cambia el comentario.
ALTER TABLE Usuarios
    MODIFY password_hash VARCHAR(64) NOT NULL
        COMMENT 'BCrypt ($2a$...). SHA-256 hex solo en filas antiguas; se rehashea al hacer login';

-- DNI del propietario: lo necesita el contrato en PDF (ARRENDADOR_DNI), que
-- antes llevaba "00000000A" escrito a mano. Opcional: si falta, el PDF
-- deja el hueco en blanco.
ALTER TABLE Usuarios
    ADD COLUMN dni VARCHAR(20) NULL AFTER email;

-- 2) Propietario de cada piso.
ALTER TABLE Pisos
    ADD COLUMN id_propietario INT NULL;

-- Los pisos existentes pasan al administrador principal. Hay DOS usuarios
-- admin (id 1 admin@gestionap.com e id 3): se usa el
-- primero por email. Cambia el email aquí si debe ser el otro.
UPDATE Pisos
SET id_propietario = (SELECT id_usuario FROM Usuarios WHERE email = 'admin@gestionap.com')
WHERE id_propietario IS NULL;

-- Si el UPDATE anterior no encontró el email, esto falla y no deja pisos huérfanos.
ALTER TABLE Pisos
    MODIFY id_propietario INT NOT NULL,
    ADD CONSTRAINT fk_pisos_propietario
        FOREIGN KEY (id_propietario) REFERENCES Usuarios (id_usuario),
    ADD INDEX idx_pisos_propietario (id_propietario);

-- 3) Enlace inquilino -> cuenta de usuario (se rellena al registrarse con invitación).
ALTER TABLE Inquilinos
    ADD COLUMN id_usuario INT NULL,
    ADD CONSTRAINT uq_inquilinos_usuario UNIQUE (id_usuario),
    ADD CONSTRAINT fk_inquilinos_usuario
        FOREIGN KEY (id_usuario) REFERENCES Usuarios (id_usuario) ON DELETE SET NULL;

-- 4) Invitaciones: un solo uso, caducan a los 7 días (lo controla la API).
-- Se guarda el SHA-256 del código, no el código: quien lea la tabla no puede
-- usar invitaciones pendientes.
CREATE TABLE Invitaciones (
    id_invitacion    INT          NOT NULL AUTO_INCREMENT,
    codigo_hash      CHAR(64)     NOT NULL,
    id_inquilino     INT          NOT NULL,
    id_creador       INT          NOT NULL,
    fecha_creacion   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion DATETIME     NOT NULL,
    fecha_uso        DATETIME     NULL,
    PRIMARY KEY (id_invitacion),
    UNIQUE KEY uq_invitaciones_codigo (codigo_hash),
    KEY idx_invitaciones_inquilino (id_inquilino),
    CONSTRAINT fk_invitaciones_inquilino
        FOREIGN KEY (id_inquilino) REFERENCES Inquilinos (id_inquilino) ON DELETE CASCADE,
    CONSTRAINT fk_invitaciones_creador
        FOREIGN KEY (id_creador) REFERENCES Usuarios (id_usuario) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
