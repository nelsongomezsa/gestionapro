-- =====================================================================
-- gestionapro-api · Migración V12 (garajes y trasteros)
-- Base de datos: gestion_alquileres_pro. Después de V11.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_v12.sql
--   mysql -u root gestion_alquileres_pro < V12__garajes_trasteros.sql
--
-- Compatibilidad con el escritorio: solo AÑADE columnas con valor por defecto (o que admiten NULL).
-- Lo existente queda como vivienda con habitaciones, sin IVA. Las columnas van al final de cada
-- tabla: un INSERT que nombre sus columnas o un SELECT * leído por posición siguen funcionando.
-- =====================================================================

-- Tipo de inmueble: un piso con habitaciones, un edificio (o planta) de garajes o uno de trasteros.
ALTER TABLE Pisos
    ADD COLUMN tipo ENUM('vivienda','garajes','trasteros') NOT NULL DEFAULT 'vivienda'
        COMMENT 'V12: tipo de inmueble';

-- Cada unidad alquilable: habitación, plaza de garaje o trastero, con sus datos opcionales.
ALTER TABLE Habitaciones
    ADD COLUMN tipo ENUM('habitacion','plaza','trastero') NOT NULL DEFAULT 'habitacion'
        COMMENT 'V12: tipo de unidad',
    ADD COLUMN metros DECIMAL(6,2) NULL COMMENT 'V12: superficie en m² (opcional)',
    ADD COLUMN planta VARCHAR(20) NULL COMMENT 'V12: planta, p. ej. -1 (opcional)',
    ADD COLUMN vehiculo ENUM('coche','moto') NULL COMMENT 'V12: solo plazas de garaje';

-- IVA por contrato (garajes y trasteros). precio_mensual sigue siendo lo que paga el inquilino
-- (IVA incluido si se aplica), para que cobros, atrasados y estadísticas no cambien.
ALTER TABLE Contratos
    ADD COLUMN aplica_iva TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'V12: el recibo desglosa base e IVA',
    ADD COLUMN iva_pct DECIMAL(5,2) NULL COMMENT 'V12: porcentaje de IVA si aplica_iva';

-- El recibo guarda el desglose del día en que se emitió (no cambia si después se edita el contrato).
ALTER TABLE Recibos
    ADD COLUMN base_imponible DECIMAL(8,2) NULL COMMENT 'V12: base sin IVA; NULL si el recibo no lleva IVA',
    ADD COLUMN iva_pct DECIMAL(5,2) NULL COMMENT 'V12',
    ADD COLUMN cuota_iva DECIMAL(8,2) NULL COMMENT 'V12';
