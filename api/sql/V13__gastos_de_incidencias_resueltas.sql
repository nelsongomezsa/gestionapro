-- =====================================================================
-- gestionapro-api · Migración V13 (gastos de incidencias resueltas)
-- Base de datos: gestion_alquileres_pro. Después de V12. Solo datos: no cambia el esquema.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_v13.sql
--   mysql -u root gestion_alquileres_pro < V13__gastos_de_incidencias_resueltas.sql
--
-- A partir de esta versión de la API el coste de reparación pasa a Gastos al marcar la incidencia como resuelta
-- y los informes ya no lo apuntan al consultarse. Este script apunta, una sola vez, las incidencias
-- que ya estaban resueltas con coste y todavía no tienen gasto (p. ej., resueltas en el escritorio
-- o nunca consultadas en un informe), con los mismos valores que ponía la API.
--
-- Idempotente: no duplica nada (Gastos.id_incidencia es UNIQUE y solo entran las que no tienen
-- gasto) y se puede volver a ejecutar sin efecto. Los gastos ya apuntados no se tocan.
-- =====================================================================

INSERT INTO Gastos (id_piso, id_habitacion, id_incidencia, categoria, concepto, importe, fecha, deducible, fecha_alta)
SELECT h.id_piso,
       i.id_habitacion,
       i.id_incidencia,
       'REPARACION',
       LEFT(CONCAT('Incidencia: ', i.descripcion), 150),
       i.coste_reparacion,
       i.fecha,
       1,
       NOW()
FROM Incidencias i
JOIN Habitaciones h ON h.id_habitacion = i.id_habitacion
WHERE i.estado = 'resuelta'
  AND i.coste_reparacion > 0
  AND NOT EXISTS (SELECT 1 FROM Gastos g WHERE g.id_incidencia = i.id_incidencia);
