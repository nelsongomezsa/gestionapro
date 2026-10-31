-- =====================================================================
-- gestionapro-api · Esquema completo (escritorio + V1–V7), SIN datos.
-- Para crear la base en un servidor nuevo (ver docs/DESPLIEGUE.md):
--   mysql -h <host> -u <usuario> -p <base> < esquema_completo.sql
-- Generado con mysqldump --no-data a partir de gestion_alquileres_pro (MariaDB 10.4).
-- =====================================================================

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ActualizacionesRenta` (
  `id_actualizacion` int(11) NOT NULL AUTO_INCREMENT,
  `id_contrato` int(11) NOT NULL,
  `fecha_efecto` date NOT NULL,
  `indice` varchar(10) NOT NULL,
  `periodo_indice` varchar(7) DEFAULT NULL,
  `porcentaje` decimal(6,3) NOT NULL,
  `renta_anterior` decimal(8,2) NOT NULL,
  `renta_nueva` decimal(8,2) NOT NULL,
  `fuente` varchar(255) DEFAULT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `fecha_confirmacion` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id_actualizacion`),
  UNIQUE KEY `uk_actualizacion_contrato_fecha` (`id_contrato`,`fecha_efecto`),
  KEY `fk_actualizacion_usuario` (`id_usuario`),
  CONSTRAINT `fk_actualizacion_contrato` FOREIGN KEY (`id_contrato`) REFERENCES `Contratos` (`id_contrato`) ON DELETE CASCADE,
  CONSTRAINT `fk_actualizacion_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `Usuarios` (`id_usuario`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Ciudades` (
  `id_ciudad` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  PRIMARY KEY (`id_ciudad`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Contratos` (
  `id_contrato` int(11) NOT NULL AUTO_INCREMENT,
  `id_habitacion` int(11) NOT NULL,
  `id_inquilino` int(11) NOT NULL,
  `fecha_inicio` date NOT NULL,
  `fecha_fin` date NOT NULL,
  `precio_mensual` decimal(8,2) NOT NULL,
  PRIMARY KEY (`id_contrato`),
  KEY `id_habitacion` (`id_habitacion`),
  KEY `id_inquilino` (`id_inquilino`),
  CONSTRAINT `contratos_ibfk_1` FOREIGN KEY (`id_habitacion`) REFERENCES `Habitaciones` (`id_habitacion`),
  CONSTRAINT `contratos_ibfk_2` FOREIGN KEY (`id_inquilino`) REFERENCES `Inquilinos` (`id_inquilino`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `DatosPiso` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_piso` int(11) NOT NULL,
  `precio_compra` decimal(10,2) DEFAULT 0.00,
  `itp_pagado` decimal(10,2) DEFAULT 0.00,
  `gastos_notaria` decimal(10,2) DEFAULT 0.00,
  `gastos_registro` decimal(10,2) DEFAULT 0.00,
  `coste_reforma` decimal(10,2) DEFAULT 0.00,
  `coste_mobiliario` decimal(10,2) DEFAULT 0.00,
  `otros_gastos_compra` decimal(10,2) DEFAULT 0.00,
  `tiene_hipoteca` tinyint(1) DEFAULT 0,
  `importe_hipoteca` decimal(10,2) DEFAULT 0.00,
  `tipo_interes` decimal(5,2) DEFAULT 0.00,
  `plazo_anos` int(11) DEFAULT 0,
  `cuota_mensual_hipoteca` decimal(10,2) DEFAULT 0.00,
  `gasto_ibi_anual` decimal(10,2) DEFAULT 0.00,
  `gasto_comunidad_mensual` decimal(10,2) DEFAULT 0.00,
  `gasto_seguro_anual` decimal(10,2) DEFAULT 0.00,
  `gasto_mantenimiento_anual` decimal(10,2) DEFAULT 0.00,
  `valor_mercado_actual` decimal(10,2) DEFAULT 0.00,
  `fecha_compra` date DEFAULT NULL,
  `notas` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id_piso` (`id_piso`),
  CONSTRAINT `datospiso_ibfk_1` FOREIGN KEY (`id_piso`) REFERENCES `Pisos` (`id_piso`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ElementosInventario` (
  `id_elemento` int(11) NOT NULL AUTO_INCREMENT,
  `id_inventario` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `estado` varchar(10) NOT NULL,
  `observaciones` varchar(255) DEFAULT NULL,
  `foto_ruta` varchar(255) DEFAULT NULL,
  `foto_tipo` varchar(50) DEFAULT NULL,
  `orden` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id_elemento`),
  KEY `fk_elementos_inventario` (`id_inventario`),
  CONSTRAINT `fk_elementos_inventario` FOREIGN KEY (`id_inventario`) REFERENCES `Inventarios` (`id_inventario`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Fianzas` (
  `id_fianza` int(11) NOT NULL AUTO_INCREMENT,
  `id_contrato` int(11) NOT NULL,
  `importe` decimal(8,2) NOT NULL,
  `fecha_cobro` date DEFAULT NULL,
  `fecha_deposito` date DEFAULT NULL,
  `organismo_deposito` varchar(150) DEFAULT NULL,
  `referencia_deposito` varchar(100) DEFAULT NULL,
  `fecha_devolucion` date DEFAULT NULL,
  `importe_devuelto` decimal(8,2) DEFAULT NULL,
  `motivo_retencion` varchar(255) DEFAULT NULL,
  `notas` text DEFAULT NULL,
  PRIMARY KEY (`id_fianza`),
  UNIQUE KEY `uk_fianzas_contrato` (`id_contrato`),
  CONSTRAINT `fk_fianzas_contrato` FOREIGN KEY (`id_contrato`) REFERENCES `Contratos` (`id_contrato`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FirmasContrato` (
  `id_firma` int(11) NOT NULL AUTO_INCREMENT,
  `id_contrato` int(11) NOT NULL,
  `parte` varchar(12) NOT NULL,
  `nombre` varchar(150) NOT NULL,
  `dni` varchar(20) DEFAULT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `imagen_ruta` varchar(255) NOT NULL,
  `fecha` datetime NOT NULL DEFAULT current_timestamp(),
  `ip` varchar(45) DEFAULT NULL,
  `huella_pdf` varchar(64) NOT NULL,
  `proveedor` varchar(30) NOT NULL DEFAULT 'EN_PANTALLA',
  PRIMARY KEY (`id_firma`),
  UNIQUE KEY `uk_firma_contrato_parte` (`id_contrato`,`parte`),
  KEY `fk_firmas_usuario` (`id_usuario`),
  CONSTRAINT `fk_firmas_contrato` FOREIGN KEY (`id_contrato`) REFERENCES `Contratos` (`id_contrato`) ON DELETE CASCADE,
  CONSTRAINT `fk_firmas_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `Usuarios` (`id_usuario`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FotosIncidencia` (
  `id_foto` int(11) NOT NULL AUTO_INCREMENT,
  `id_incidencia` int(11) NOT NULL,
  `ruta` varchar(255) NOT NULL,
  `tipo` varchar(50) NOT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `fecha` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id_foto`),
  KEY `fk_fotos_incidencia` (`id_incidencia`),
  KEY `fk_fotos_usuario` (`id_usuario`),
  CONSTRAINT `fk_fotos_incidencia` FOREIGN KEY (`id_incidencia`) REFERENCES `Incidencias` (`id_incidencia`) ON DELETE CASCADE,
  CONSTRAINT `fk_fotos_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `Usuarios` (`id_usuario`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Gastos` (
  `id_gasto` int(11) NOT NULL AUTO_INCREMENT,
  `id_piso` int(11) NOT NULL,
  `id_habitacion` int(11) DEFAULT NULL,
  `id_incidencia` int(11) DEFAULT NULL,
  `categoria` varchar(20) NOT NULL,
  `concepto` varchar(200) NOT NULL,
  `importe` decimal(10,2) NOT NULL,
  `fecha` date NOT NULL,
  `deducible` tinyint(1) NOT NULL DEFAULT 1,
  `factura_ruta` varchar(255) DEFAULT NULL,
  `factura_tipo` varchar(50) DEFAULT NULL,
  `fecha_alta` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id_gasto`),
  UNIQUE KEY `uk_gastos_incidencia` (`id_incidencia`),
  KEY `fk_gastos_habitacion` (`id_habitacion`),
  KEY `idx_gastos_piso_fecha` (`id_piso`,`fecha`),
  CONSTRAINT `fk_gastos_habitacion` FOREIGN KEY (`id_habitacion`) REFERENCES `Habitaciones` (`id_habitacion`) ON DELETE SET NULL,
  CONSTRAINT `fk_gastos_incidencia` FOREIGN KEY (`id_incidencia`) REFERENCES `Incidencias` (`id_incidencia`) ON DELETE SET NULL,
  CONSTRAINT `fk_gastos_piso` FOREIGN KEY (`id_piso`) REFERENCES `Pisos` (`id_piso`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Habitaciones` (
  `id_habitacion` int(11) NOT NULL AUTO_INCREMENT,
  `numero` int(11) NOT NULL,
  `precio` decimal(8,2) NOT NULL,
  `estado` enum('disponible','alquilada','mantenimiento') NOT NULL DEFAULT 'disponible',
  `id_piso` int(11) NOT NULL,
  PRIMARY KEY (`id_habitacion`),
  KEY `id_piso` (`id_piso`),
  CONSTRAINT `habitaciones_ibfk_1` FOREIGN KEY (`id_piso`) REFERENCES `Pisos` (`id_piso`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Incidencias` (
  `id_incidencia` int(11) NOT NULL AUTO_INCREMENT,
  `id_habitacion` int(11) NOT NULL,
  `id_inquilino` int(11) NOT NULL,
  `descripcion` varchar(255) NOT NULL,
  `estado` enum('pendiente','en_proceso','resuelta') NOT NULL DEFAULT 'pendiente',
  `fecha` date NOT NULL,
  `coste_reparacion` decimal(8,2) DEFAULT 0.00 COMMENT 'Coste estimado o real de reparación de la incidencia',
  PRIMARY KEY (`id_incidencia`),
  KEY `id_habitacion` (`id_habitacion`),
  KEY `id_inquilino` (`id_inquilino`),
  CONSTRAINT `incidencias_ibfk_1` FOREIGN KEY (`id_habitacion`) REFERENCES `Habitaciones` (`id_habitacion`),
  CONSTRAINT `incidencias_ibfk_2` FOREIGN KEY (`id_inquilino`) REFERENCES `Inquilinos` (`id_inquilino`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Inquilinos` (
  `id_inquilino` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `apellidos` varchar(100) NOT NULL,
  `dni` varchar(20) NOT NULL,
  `telefono` varchar(20) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `id_propietario` int(11) DEFAULT NULL,
  PRIMARY KEY (`id_inquilino`),
  UNIQUE KEY `dni` (`dni`),
  UNIQUE KEY `uq_inquilinos_usuario` (`id_usuario`),
  KEY `idx_inquilinos_propietario` (`id_propietario`),
  CONSTRAINT `fk_inquilinos_propietario` FOREIGN KEY (`id_propietario`) REFERENCES `Usuarios` (`id_usuario`) ON DELETE SET NULL,
  CONSTRAINT `fk_inquilinos_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `Usuarios` (`id_usuario`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Inventarios` (
  `id_inventario` int(11) NOT NULL AUTO_INCREMENT,
  `id_habitacion` int(11) NOT NULL,
  `id_contrato` int(11) DEFAULT NULL,
  `tipo` varchar(10) NOT NULL,
  `fecha` date NOT NULL,
  `observaciones` text DEFAULT NULL,
  `fecha_alta` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id_inventario`),
  KEY `fk_inventarios_habitacion` (`id_habitacion`),
  KEY `fk_inventarios_contrato` (`id_contrato`),
  CONSTRAINT `fk_inventarios_contrato` FOREIGN KEY (`id_contrato`) REFERENCES `Contratos` (`id_contrato`) ON DELETE SET NULL,
  CONSTRAINT `fk_inventarios_habitacion` FOREIGN KEY (`id_habitacion`) REFERENCES `Habitaciones` (`id_habitacion`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Invitaciones` (
  `id_invitacion` int(11) NOT NULL AUTO_INCREMENT,
  `codigo_hash` char(64) NOT NULL,
  `id_inquilino` int(11) NOT NULL,
  `id_creador` int(11) NOT NULL,
  `fecha_creacion` datetime NOT NULL DEFAULT current_timestamp(),
  `fecha_expiracion` datetime NOT NULL,
  `fecha_uso` datetime DEFAULT NULL,
  PRIMARY KEY (`id_invitacion`),
  UNIQUE KEY `uq_invitaciones_codigo` (`codigo_hash`),
  KEY `idx_invitaciones_inquilino` (`id_inquilino`),
  KEY `fk_invitaciones_creador` (`id_creador`),
  CONSTRAINT `fk_invitaciones_creador` FOREIGN KEY (`id_creador`) REFERENCES `Usuarios` (`id_usuario`) ON DELETE CASCADE,
  CONSTRAINT `fk_invitaciones_inquilino` FOREIGN KEY (`id_inquilino`) REFERENCES `Inquilinos` (`id_inquilino`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Mensajes` (
  `id_mensaje` int(11) NOT NULL AUTO_INCREMENT,
  `id_contrato` int(11) NOT NULL,
  `id_incidencia` int(11) DEFAULT NULL,
  `id_autor` int(11) DEFAULT NULL,
  `texto` text NOT NULL,
  `fecha` datetime NOT NULL DEFAULT current_timestamp(),
  `leido` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id_mensaje`),
  KEY `fk_mensajes_incidencia` (`id_incidencia`),
  KEY `fk_mensajes_autor` (`id_autor`),
  KEY `idx_mensajes_contrato_fecha` (`id_contrato`,`fecha`),
  CONSTRAINT `fk_mensajes_autor` FOREIGN KEY (`id_autor`) REFERENCES `Usuarios` (`id_usuario`) ON DELETE SET NULL,
  CONSTRAINT `fk_mensajes_contrato` FOREIGN KEY (`id_contrato`) REFERENCES `Contratos` (`id_contrato`) ON DELETE CASCADE,
  CONSTRAINT `fk_mensajes_incidencia` FOREIGN KEY (`id_incidencia`) REFERENCES `Incidencias` (`id_incidencia`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Notificaciones` (
  `id_notificacion` int(11) NOT NULL AUTO_INCREMENT,
  `tipo` varchar(50) NOT NULL,
  `titulo` varchar(200) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `referencia` varchar(100) DEFAULT NULL,
  `fecha` datetime NOT NULL DEFAULT current_timestamp(),
  `leida` tinyint(1) NOT NULL DEFAULT 0,
  `id_usuario` int(11) NOT NULL,
  PRIMARY KEY (`id_notificacion`),
  KEY `idx_notif_usuario_leida` (`id_usuario`,`leida`),
  KEY `idx_notif_referencia` (`referencia`,`fecha`),
  CONSTRAINT `notificaciones_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `Usuarios` (`id_usuario`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Pagos` (
  `id_pago` int(11) NOT NULL AUTO_INCREMENT,
  `id_contrato` int(11) NOT NULL,
  `cantidad` decimal(8,2) NOT NULL,
  `metodo_pago` enum('transferencia','efectivo','domiciliacion') NOT NULL DEFAULT 'transferencia',
  `fecha_pago` date NOT NULL,
  PRIMARY KEY (`id_pago`),
  KEY `id_contrato` (`id_contrato`),
  CONSTRAINT `pagos_ibfk_1` FOREIGN KEY (`id_contrato`) REFERENCES `Contratos` (`id_contrato`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Pisos` (
  `id_piso` int(11) NOT NULL AUTO_INCREMENT,
  `direccion` varchar(150) NOT NULL,
  `numero_habitaciones` int(11) NOT NULL,
  `id_ciudad` int(11) NOT NULL,
  `id_propietario` int(11) NOT NULL,
  PRIMARY KEY (`id_piso`),
  KEY `id_ciudad` (`id_ciudad`),
  KEY `idx_pisos_propietario` (`id_propietario`),
  CONSTRAINT `fk_pisos_propietario` FOREIGN KEY (`id_propietario`) REFERENCES `Usuarios` (`id_usuario`),
  CONSTRAINT `pisos_ibfk_1` FOREIGN KEY (`id_ciudad`) REFERENCES `Ciudades` (`id_ciudad`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Recibos` (
  `id_recibo` int(11) NOT NULL AUTO_INCREMENT,
  `id_pago` int(11) NOT NULL,
  `id_propietario` int(11) NOT NULL,
  `anio` int(11) NOT NULL,
  `numero` int(11) NOT NULL,
  `fecha_emision` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id_recibo`),
  UNIQUE KEY `uk_recibos_pago` (`id_pago`),
  UNIQUE KEY `uk_recibos_numero` (`id_propietario`,`anio`,`numero`),
  CONSTRAINT `fk_recibos_pago` FOREIGN KEY (`id_pago`) REFERENCES `Pagos` (`id_pago`) ON DELETE CASCADE,
  CONSTRAINT `fk_recibos_propietario` FOREIGN KEY (`id_propietario`) REFERENCES `Usuarios` (`id_usuario`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Usuarios` (
  `id_usuario` int(11) NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `dni` varchar(20) DEFAULT NULL,
  `iban` varchar(34) DEFAULT NULL,
  `password_hash` varchar(64) NOT NULL COMMENT 'BCrypt ($2a$...). SHA-256 hex solo en filas antiguas; se rehashea al hacer login',
  `rol` enum('admin','usuario','inquilino') NOT NULL DEFAULT 'usuario',
  `activo` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id_usuario`),
  UNIQUE KEY `uq_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `actividad` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_usuario` int(11) DEFAULT NULL,
  `accion` varchar(100) DEFAULT NULL,
  `descripcion` varchar(255) DEFAULT NULL,
  `fecha` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_actividad_usuario` (`id_usuario`,`fecha`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_spanish_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

