-- =====================================================================
-- gestionapro-api · Limpieza de avisos duplicados (datos, no esquema)
-- Base de datos: gestion_alquileres_pro.
--
--   mysqldump -u root gestion_alquileres_pro > ~/gestionap-backups/antes_limpieza_avisos.sql
--   mysql -u root gestion_alquileres_pro < demo_notificaciones_duplicadas.sql
--
-- El escritorio volvía a crear cada día los avisos que seguían sin leer (mismo usuario y
-- misma referencia, p. ej. "incidencia_antigua_16" siete veces). Se deja una copia por
-- usuario y referencia: la más antigua, sin leer si alguna copia lo estaba.
-- =====================================================================

UPDATE Notificaciones n
JOIN (SELECT id_usuario, referencia, MIN(id_notificacion) AS primera, MIN(leida) AS leida
      FROM Notificaciones WHERE referencia IS NOT NULL
      GROUP BY id_usuario, referencia HAVING COUNT(*) > 1) d
  ON n.id_notificacion = d.primera
SET n.leida = d.leida;

DELETE n FROM Notificaciones n
JOIN (SELECT id_usuario, referencia, MIN(id_notificacion) AS primera
      FROM Notificaciones WHERE referencia IS NOT NULL
      GROUP BY id_usuario, referencia HAVING COUNT(*) > 1) d
  ON n.id_usuario = d.id_usuario AND n.referencia = d.referencia AND n.id_notificacion <> d.primera;
