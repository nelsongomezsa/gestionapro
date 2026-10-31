-- =====================================================================
-- gestionapro-api · Fechas de las fianzas de demo (datos, no esquema)
-- Base de datos: gestion_alquileres_pro. Después de V4.
--
-- Las fianzas de demo se crearon con la fecha del día de prueba (30-10-2026) como entrega y
-- depósito. Lo coherente es la fecha de inicio del contrato: la fianza se entrega al firmar
-- y se deposita ese mismo día en estos datos de ejemplo.
-- Solo toca las fianzas cuya entrega es posterior al inicio del contrato.
-- =====================================================================

UPDATE Fianzas f
JOIN Contratos c ON c.id_contrato = f.id_contrato
SET f.fecha_cobro = c.fecha_inicio,
    f.fecha_deposito = CASE WHEN f.fecha_deposito IS NULL THEN NULL ELSE c.fecha_inicio END
WHERE f.fecha_cobro IS NULL OR f.fecha_cobro > c.fecha_inicio;
