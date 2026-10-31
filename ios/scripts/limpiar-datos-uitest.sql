-- Retira lo que crean los tests de UI (habitación 990 y sus contratos, firmas y mensajes).
-- Solo para la base de pruebas: capturas.sh se niega a ejecutarlo contra gestion_alquileres_pro.
DELETE c FROM Contratos c JOIN Habitaciones h ON h.id_habitacion = c.id_habitacion WHERE h.numero = 990;
DELETE FROM Habitaciones WHERE numero = 990;
