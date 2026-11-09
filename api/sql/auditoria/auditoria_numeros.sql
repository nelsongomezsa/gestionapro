-- =====================================================================
-- Auditoría de cifras: se calculan con SQL directo para compararlas con la API y la app.
-- Solo lecturas. Úsese contra la copia de pruebas:
--   mysql -u root gestionapro_api_verif < auditoria_numeros.sql
-- Ámbito: toda la cartera (lo que ve el admin). Fechas relativas a CURDATE().
-- =====================================================================
SET @hoy = CURDATE();
SET @ini = DATE_FORMAT(@hoy, '%Y-%m-01');
SET @fin = LAST_DAY(@hoy);

-- 1) Inicio: cobrado, esperado y pendiente del mes en curso
SELECT 'cobrado_mes' AS cifra, COALESCE(SUM(cantidad), 0) AS valor
  FROM Pagos WHERE fecha_pago BETWEEN @ini AND @fin
UNION ALL
SELECT 'esperado_activos_hoy (Inicio, panel)', SUM(precio_mensual)
  FROM Contratos WHERE fecha_inicio <= @hoy AND fecha_fin >= @hoy
UNION ALL
SELECT 'esperado_vigentes_mes (Cobros)', SUM(precio_mensual)
  FROM Contratos WHERE fecha_inicio <= @fin AND fecha_fin >= @ini
UNION ALL
SELECT 'pendiente_sin_pago_mes (Cobros)', COALESCE(SUM(c.precio_mensual), 0)
  FROM Contratos c
 WHERE c.fecha_inicio <= @fin AND c.fecha_fin >= @ini
   AND NOT EXISTS (SELECT 1 FROM Pagos p WHERE p.id_contrato = c.id_contrato AND p.fecha_pago BETWEEN @ini AND @fin);

-- 2) Métricas por piso (mismo cálculo que CalculadoraFinancieraPiso, con gastos reales de 12 meses)
DROP TEMPORARY TABLE IF EXISTS metricas;
CREATE TEMPORARY TABLE metricas AS
SELECT x.*,
       ROUND(x.ingresos - x.cuota - ROUND(x.gastos_anuales / 12, 2), 2) AS cash_flow_mes
  FROM (
    SELECT p.id_piso, p.direccion,
           COALESCE((SELECT SUM(c.precio_mensual) FROM Contratos c JOIN Habitaciones h ON h.id_habitacion = c.id_habitacion
                      WHERE h.id_piso = p.id_piso AND c.fecha_inicio <= @hoy AND c.fecha_fin >= @hoy), 0) AS ingresos,
           d.precio_compra + d.itp_pagado + d.gastos_notaria + d.gastos_registro + d.coste_reforma
             + d.coste_mobiliario + d.otros_gastos_compra AS inversion,
           IF(d.tiene_hipoteca AND d.importe_hipoteca > 0 AND d.plazo_anos > 0,
              ROUND(IF(d.tipo_interes = 0, d.importe_hipoteca / (d.plazo_anos * 12),
                       d.importe_hipoteca * (d.tipo_interes / 1200) * POW(1 + d.tipo_interes / 1200, d.plazo_anos * 12)
                         / (POW(1 + d.tipo_interes / 1200, d.plazo_anos * 12) - 1)), 2), 0) AS cuota,
           IF(d.tiene_hipoteca, d.importe_hipoteca, 0) AS hipoteca,
           -- Cada categoría real sustituye a su estimación (como en PisoService.metricas)
           COALESCE(g.ibi, d.gasto_ibi_anual)
             + IF(g.comunidad IS NULL, d.gasto_comunidad_mensual, ROUND(g.comunidad / 12, 2)) * 12
             + COALESCE(g.seguro, d.gasto_seguro_anual)
             + COALESCE(g.mantenimiento, d.gasto_mantenimiento_anual) AS gastos_anuales
      FROM Pisos p
      JOIN DatosPiso d ON d.id_piso = p.id_piso
      LEFT JOIN (
        SELECT id_piso,
               SUM(IF(categoria = 'IBI', importe, NULL)) AS ibi,
               SUM(IF(categoria = 'COMUNIDAD', importe, NULL)) AS comunidad,
               SUM(IF(categoria = 'SEGURO', importe, NULL)) AS seguro,
               SUM(IF(categoria IN ('REPARACION','MANTENIMIENTO','SUMINISTROS','GESTION','OTROS'), importe, NULL)) AS mantenimiento
          FROM Gastos WHERE fecha BETWEEN @hoy - INTERVAL 12 MONTH AND @hoy GROUP BY id_piso
      ) g ON g.id_piso = p.id_piso
  ) x;

SELECT 'cash_flow_previsto (suma de pisos)' AS cifra, SUM(cash_flow_mes) AS valor FROM metricas;

SELECT id_piso, direccion, ingresos, inversion, cuota, gastos_anuales, cash_flow_mes,
       ROUND(ingresos * 12 / inversion * 100, 2) AS bruta_pct,
       ROUND((ingresos * 12 - gastos_anuales) / inversion * 100, 2) AS neta_pct,
       IF(inversion - hipoteca > 0, ROUND(cash_flow_mes * 12 / (inversion - hipoteca) * 100, 2), NULL) AS coc_pct,
       IF(ingresos > 0, ROUND(inversion / (ingresos * 12), 2), NULL) AS per_anios
  FROM metricas ORDER BY id_piso;

-- 3) Cobros atrasados: meses M-12..M-1 con contrato vigente y sin ningún pago en el mes
WITH RECURSIVE meses AS (
    SELECT DATE_FORMAT(@hoy - INTERVAL 12 MONTH, '%Y-%m-01') AS m
    UNION ALL SELECT m + INTERVAL 1 MONTH FROM meses WHERE m + INTERVAL 1 MONTH < @ini
)
SELECT 'atrasados' AS cifra, COUNT(*) AS numero, SUM(c.precio_mensual) AS importe
  FROM meses JOIN Contratos c ON c.fecha_inicio <= LAST_DAY(meses.m) AND c.fecha_fin >= meses.m
 WHERE NOT EXISTS (SELECT 1 FROM Pagos p WHERE p.id_contrato = c.id_contrato
                     AND p.fecha_pago BETWEEN meses.m AND LAST_DAY(meses.m));

-- 4) Estadísticas de un trimestre (por defecto el 3.º del año en curso)
SET @tini = MAKEDATE(YEAR(@hoy), 1) + INTERVAL 6 MONTH;
SET @tfin = LAST_DAY(@tini + INTERVAL 2 MONTH);
SELECT 'trim_ingresos' AS cifra, COALESCE(SUM(cantidad), 0) AS valor FROM Pagos WHERE fecha_pago BETWEEN @tini AND @tfin
UNION ALL
SELECT 'trim_gastos', COALESCE(SUM(importe), 0) FROM Gastos WHERE fecha BETWEEN @tini AND @tfin;

WITH RECURSIVE dias AS (
    SELECT @tini AS d UNION ALL SELECT d + INTERVAL 1 DAY FROM dias WHERE d < LEAST(@tfin, @hoy)
)
SELECT 'trim_ocupacion_pct' AS cifra,
       ROUND(SUM(EXISTS(SELECT 1 FROM Contratos c WHERE c.id_habitacion = h.id_habitacion
                          AND dias.d BETWEEN c.fecha_inicio AND c.fecha_fin)) * 100 / COUNT(*), 2) AS valor,
       ROUND((COUNT(*) - SUM(EXISTS(SELECT 1 FROM Contratos c WHERE c.id_habitacion = h.id_habitacion
                          AND dias.d BETWEEN c.fecha_inicio AND c.fecha_fin))) / COUNT(DISTINCT h.id_habitacion), 2) AS dias_medios_vacia
  FROM dias CROSS JOIN Habitaciones h;

WITH RECURSIVE meses AS (
    SELECT @tini AS m UNION ALL SELECT m + INTERVAL 1 MONTH FROM meses WHERE m + INTERVAL 1 MONTH <= @tfin
)
SELECT 'trim_impagado' AS cifra, COALESCE(SUM(c.precio_mensual), 0) AS valor
  FROM meses JOIN Contratos c ON c.fecha_inicio <= LAST_DAY(meses.m) AND c.fecha_fin >= meses.m
 WHERE meses.m < @ini
   AND NOT EXISTS (SELECT 1 FROM Pagos p WHERE p.id_contrato = c.id_contrato
                     AND p.fecha_pago BETWEEN meses.m AND LAST_DAY(meses.m));

SELECT 'trim_contratos_iniciados' AS cifra, COUNT(*) AS valor FROM Contratos WHERE fecha_inicio BETWEEN @tini AND @tfin
UNION ALL
SELECT 'trim_contratos_finalizados', COUNT(*) FROM Contratos WHERE fecha_fin BETWEEN @tini AND LEAST(@tfin, @hoy);

-- 5) Ocupación y unidades libres (Inicio). Un contrato finalizado hoy sigue vigente hasta medianoche
--    (su fecha de fin es hoy) pero su unidad ya está libre: por eso activos puede superar a alquiladas.
SELECT COUNT(*) AS unidades, SUM(estado = 'alquilada') AS alquiladas, SUM(estado = 'disponible') AS libres,
       SUM(estado = 'mantenimiento') AS mantenimiento,
       ROUND(SUM(estado = 'alquilada') * 100 / COUNT(*), 2) AS ocupacion_pct
  FROM Habitaciones;

-- 6) Contratos activos y por vencer en 30 días, y cuántos de ellos ya se finalizaron hoy
SELECT COUNT(*) AS activos, SUM(c.fecha_fin <= @hoy + INTERVAL 30 DAY) AS por_vencer,
       SUM(c.fecha_fin = @hoy AND h.estado <> 'alquilada') AS finalizados_hoy
  FROM Contratos c JOIN Habitaciones h USING (id_habitacion)
 WHERE @hoy BETWEEN c.fecha_inicio AND c.fecha_fin;

-- 7) IVA de los recibos: la renta guardada es el total; base = total / (1 + %), cuota = total - base
SELECT COUNT(*) AS recibos_con_iva, ROUND(SUM(p.cantidad), 2) AS total, ROUND(SUM(r.base_imponible), 2) AS base,
       ROUND(SUM(r.cuota_iva), 2) AS cuota, SUM(r.base_imponible + r.cuota_iva <> p.cantidad) AS descuadrados
  FROM Recibos r JOIN Pagos p USING (id_pago) WHERE r.base_imponible IS NOT NULL;

-- 8) Gastos por incidencias: cada incidencia resuelta con coste tiene su gasto, por el mismo importe y fecha
SELECT COUNT(*) AS gastos, ROUND(SUM(g.importe), 2) AS importe,
       SUM(g.importe <> i.coste_reparacion OR g.fecha <> i.fecha) AS descuadrados,
       SUM(i.estado <> 'resuelta') AS de_no_resueltas
  FROM Gastos g JOIN Incidencias i ON i.id_incidencia = g.id_incidencia;
SELECT COUNT(*) AS resueltas_con_coste_sin_gasto
  FROM Incidencias i LEFT JOIN Gastos g ON g.id_incidencia = i.id_incidencia
 WHERE i.estado = 'resuelta' AND i.coste_reparacion > 0 AND g.id_gasto IS NULL;
