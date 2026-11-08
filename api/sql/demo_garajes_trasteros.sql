-- =====================================================================
-- gestionapro-api · Datos de demo de garajes y trasteros (inventados; no es una migración)
-- Requiere V12. Pensado para la base de pruebas:
--
--   mysql -u root gestionapro_api_verif < demo_garajes_trasteros.sql
--
-- Crea, para el usuario admin@gestionap.com, un garaje en Madrid (12 plazas, 7 alquiladas, dos con
-- IVA) y un edificio de trasteros en Valencia (8 trasteros, 4 alquilados), con sus inquilinos
-- (DNI 000001NN con letra válida, emails @example.com, teléfonos 600 000 1NN), contratos que
-- empezaron hace 4 meses y los pagos de los meses anteriores y de este mes (salvo dos pendientes).
-- Fechas relativas a hoy. Sin procedimientos (sirve en cualquier MariaDB) e idempotente: si el
-- garaje de demo ya existe, no añade nada.
-- =====================================================================

SET @prop = (SELECT id_usuario FROM Usuarios WHERE email = 'admin@gestionap.com');
SET @nuevo = (SELECT COUNT(*) = 0 FROM Pisos WHERE direccion = 'Calle de Alcalá 120, garaje') AND @prop IS NOT NULL;
SET @inicio = DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 4 MONTH);
SET @fin = DATE_ADD(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 8 MONTH);

-- Inmuebles
INSERT INTO Pisos (direccion, numero_habitaciones, id_ciudad, id_propietario, tipo)
SELECT 'Calle de Alcalá 120, garaje', 12, c.id_ciudad, @prop, 'garajes' FROM Ciudades c WHERE c.nombre = 'Madrid' AND @nuevo;
SET @g = IF(@nuevo, LAST_INSERT_ID(), NULL);
INSERT INTO Pisos (direccion, numero_habitaciones, id_ciudad, id_propietario, tipo)
SELECT 'Carrer de Sueca 31, trasteros', 8, c.id_ciudad, @prop, 'trasteros' FROM Ciudades c WHERE c.nombre = 'Valencia' AND @nuevo;
SET @t = IF(@nuevo, LAST_INSERT_ID(), NULL);

INSERT INTO DatosPiso (id_piso, precio_compra, itp_pagado, gastos_notaria, gastos_registro, coste_reforma, coste_mobiliario,
                       otros_gastos_compra, tiene_hipoteca, gasto_ibi_anual, gasto_comunidad_mensual, gasto_seguro_anual,
                       gasto_mantenimiento_anual, valor_mercado_actual)
SELECT @g, 150000, 9000, 900, 600, 2000, 0, 0, 0, 900, 150, 240, 480, 175000 FROM DUAL WHERE @g IS NOT NULL;

-- Unidades: plazas 1-12 en dos plantas (la 11 y la 12, de moto) y trasteros 1-8.
CREATE TEMPORARY TABLE demo_n (n INT PRIMARY KEY);
INSERT INTO demo_n VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12);

INSERT INTO Habitaciones (numero, precio, estado, id_piso, tipo, metros, planta, vehiculo)
SELECT n, IF(n > 10, 45, 110), IF(n <= 7, 'alquilada', IF(n = 9, 'mantenimiento', 'disponible')), @g, 'plaza',
       IF(n > 10, 3.5, 12.5), IF(n <= 6, '-1', '-2'), IF(n > 10, 'moto', 'coche')
FROM demo_n WHERE @g IS NOT NULL;

INSERT INTO Habitaciones (numero, precio, estado, id_piso, tipo, metros, planta)
SELECT n, IF(n <= 4, 60, 85), IF(n IN (1, 2, 5, 6), 'alquilada', 'disponible'), @t, 'trastero', IF(n <= 4, 4, 7), '-1'
FROM demo_n WHERE n <= 8 AND @t IS NOT NULL;

-- Inquilinos (11): 7 de plazas y 4 de trasteros.
INSERT INTO Inquilinos (nombre, apellidos, dni, telefono, email, id_propietario)
SELECT ELT(n, 'Raúl', 'Marta', 'Diego', 'Paula', 'Sergio', 'Nuria', 'Óscar', 'Irene', 'Hugo', 'Clara', 'Iván'),
       ELT(n, 'Navarro Gil', 'Serrano Ruiz', 'Molina Vega', 'Ortiz Cano', 'Delgado Prieto', 'Herrero Lozano',
           'Marín Ibáñez', 'Cruz Pascual', 'Garrido Soler', 'Rubio Méndez', 'Santos Vidal'),
       CONCAT(LPAD(100 + n, 8, '0'), SUBSTRING('TRWAGMYFPDXBNJZSQVHLCKE', MOD(100 + n, 23) + 1, 1)),
       CONCAT('600 000 ', 100 + n), CONCAT('demo.garaje', n, '@example.com'), @prop
FROM demo_n WHERE n <= 11 AND @g IS NOT NULL;

-- Contratos: plazas 1-7 (la 1 y la 2, con IVA del 21 %: 121 € con IVA) y trasteros 1, 2, 5 y 6.
INSERT INTO Contratos (id_habitacion, id_inquilino, fecha_inicio, fecha_fin, precio_mensual, aplica_iva, iva_pct)
SELECT h.id_habitacion, q.id_inquilino, @inicio, @fin,
       IF(h.tipo = 'plaza' AND h.numero <= 2, 121.00, h.precio),
       IF(h.tipo = 'plaza' AND h.numero <= 2, 1, 0), IF(h.tipo = 'plaza' AND h.numero <= 2, 21.00, NULL)
FROM Habitaciones h
JOIN Inquilinos q ON q.email = CONCAT('demo.garaje',
        IF(h.tipo = 'plaza', h.numero, 7 + CASE h.numero WHEN 1 THEN 1 WHEN 2 THEN 2 WHEN 5 THEN 3 ELSE 4 END), '@example.com')
WHERE h.estado = 'alquilada' AND h.id_piso IN (@g, @t);

-- Pagos: los 4 meses anteriores y, este mes, todos menos la plaza 7 y el trastero 6.
INSERT INTO Pagos (id_contrato, cantidad, fecha_pago, metodo_pago)
SELECT c.id_contrato, c.precio_mensual, DATE_ADD(DATE_ADD(@inicio, INTERVAL m.n MONTH), INTERVAL 2 DAY), 'transferencia'
FROM Contratos c
JOIN Habitaciones h ON h.id_habitacion = c.id_habitacion
JOIN (SELECT n - 1 AS n FROM demo_n WHERE n <= 5) m
WHERE h.id_piso IN (@g, @t)
  AND DATE_ADD(DATE_ADD(@inicio, INTERVAL m.n MONTH), INTERVAL 2 DAY) <= CURDATE()
  AND NOT (m.n = 4 AND ((h.tipo = 'plaza' AND h.numero = 7) OR (h.tipo = 'trastero' AND h.numero = 6)));

DROP TEMPORARY TABLE demo_n;
