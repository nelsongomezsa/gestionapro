-- =====================================================================
-- Datos de demo: poner al día las fechas de contratos, pagos e incidencias.
-- Base de datos: gestion_alquileres_pro.   SE APLICA A MANO (no lo ejecuta la API).
--
-- Problema: los datos de demo eran coherentes a finales de abril de 2026 (último pago:
-- 2026-04-04). Con el paso del tiempo casi todos los contratos han "vencido": solo 8 de
-- 30 siguen activos, aunque hay 20 habitaciones marcadas como alquiladas. Por eso los
-- pisos salen sin ingresos y con cash flow negativo.
--
-- Solución: desplazar TODAS esas fechas el mismo número de meses, para que el último pago
-- caiga en el mes actual. Al mover todo junto se conservan las relaciones (cada pago sigue
-- dentro de su contrato, el historial sigue siendo historial). Comprobado en una copia
-- de la base: quedan activos los 20 contratos de las 20 habitaciones alquiladas, y
-- ninguna habitación libre o en mantenimiento queda con contrato activo.
--
-- Se puede ejecutar más de una vez: si los datos ya están al día, desplaza 0 meses.
-- Nunca deja pagos con fecha futura.
--
-- Antes:  mysqldump -u root gestion_alquileres_pro > backup_antes_demo.sql
-- Aplicar: mysql -u root gestion_alquileres_pro < demo_fechas_contratos.sql
-- =====================================================================

START TRANSACTION;

SET @ultimo_pago := (SELECT MAX(fecha_pago) FROM Pagos);
SET @meses := PERIOD_DIFF(DATE_FORMAT(CURDATE(), '%Y%m'), DATE_FORMAT(@ultimo_pago, '%Y%m'));
-- Si el último pago desplazado quedara en el futuro (p. ej. hoy es día 2 y el pago era
-- del día 4), se desplaza un mes menos.
SET @meses := GREATEST(0, @meses - (DATE_ADD(@ultimo_pago, INTERVAL @meses MONTH) > CURDATE()));

SELECT @ultimo_pago AS ultimo_pago_antes, @meses AS meses_a_desplazar;

UPDATE Contratos
SET fecha_inicio = DATE_ADD(fecha_inicio, INTERVAL @meses MONTH),
    fecha_fin    = DATE_ADD(fecha_fin,    INTERVAL @meses MONTH)
WHERE @meses > 0;

UPDATE Pagos
SET fecha_pago = DATE_ADD(fecha_pago, INTERVAL @meses MONTH)
WHERE @meses > 0;

UPDATE Incidencias
SET fecha = DATE_ADD(fecha, INTERVAL @meses MONTH)
WHERE @meses > 0;

COMMIT;

-- Comprobación: contratos activos hoy y habitaciones alquiladas sin contrato activo (debe ser 0).
SELECT
    (SELECT COUNT(*) FROM Contratos WHERE CURDATE() BETWEEN fecha_inicio AND fecha_fin) AS contratos_activos_hoy,
    (SELECT COUNT(*) FROM Habitaciones h
      WHERE h.estado = 'alquilada'
        AND NOT EXISTS (SELECT 1 FROM Contratos c
                        WHERE c.id_habitacion = h.id_habitacion
                          AND CURDATE() BETWEEN c.fecha_inicio AND c.fecha_fin)) AS alquiladas_sin_contrato,
    (SELECT MAX(fecha_pago) FROM Pagos) AS ultimo_pago_despues;
