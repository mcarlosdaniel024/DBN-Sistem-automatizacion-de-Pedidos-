-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 10-04-2025 a las 23:22:42
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.1.25

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `tienda`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_actualizar_precio` (IN `p_id_producto` INT, IN `p_nuevo_precio` DECIMAL(10,2), IN `p_tipo_cambio` VARCHAR(20), IN `p_motivo` VARCHAR(255), IN `p_id_usuario` INT, IN `p_ip_origen` VARCHAR(45), IN `p_detalles` JSON)   BEGIN
    DECLARE v_precio_actual DECIMAL(10,2);
    
    -- Obtener precio actual
    SELECT `valor_unitario` INTO v_precio_actual
    FROM `productos`
    WHERE `id_producto` = p_id_producto;
    
    -- Actualizar producto
    UPDATE `productos`
    SET `valor_unitario` = p_nuevo_precio
    WHERE `id_producto` = p_id_producto;
    
    -- Registrar en historial
    INSERT INTO `historial_precios` (
        `id_producto`,
        `precio_anterior`,
        `precio_nuevo`,
        `tipo_cambio`,
        `motivo`,
        `id_usuario`,
        `ip_origen`,
        `detalles`
    ) VALUES (
        p_id_producto,
        v_precio_actual,
        p_nuevo_precio,
        p_tipo_cambio,
        p_motivo,
        p_id_usuario,
        p_ip_origen,
        p_detalles
    );
    
    SELECT ROW_COUNT() AS filas_afectadas, LAST_INSERT_ID() AS id_historial;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_finalizar_evento` (IN `p_id_evento` INT, IN `p_estado` VARCHAR(20), IN `p_resultado` TEXT, IN `p_detalles` JSON, IN `p_registros_afectados` INT, IN `p_tamano_backup_mb` DECIMAL(10,2))   BEGIN
    UPDATE `eventos_sistema` 
    SET 
        `fecha_hora_fin` = NOW(),
        `estado` = p_estado,
        `resultado` = p_resultado,
        `detalles` = p_detalles,
        `duracion_segundos` = TIMESTAMPDIFF(SECOND, `fecha_hora_inicio`, NOW()),
        `registros_afectados` = p_registros_afectados,
        `tamano_backup_mb` = p_tamano_backup_mb
    WHERE `id_evento` = p_id_evento;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_iniciar_evento` (IN `p_tipo_evento` VARCHAR(20), IN `p_nombre_evento` VARCHAR(100), IN `p_descripcion` TEXT, IN `p_umbral_alerta` VARCHAR(50), IN `p_severidad` VARCHAR(10))   BEGIN
    INSERT INTO `eventos_sistema` (
        `tipo_evento`,
        `nombre_evento`,
        `descripcion`,
        `estado`,
        `umbral_alerta`,
        `severidad`
    ) VALUES (
        p_tipo_evento,
        p_nombre_evento,
        p_descripcion,
        'EN_EJECUCION',
        p_umbral_alerta,
        p_severidad
    );
    
    SELECT LAST_INSERT_ID() AS id_evento;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_levantar_bloqueo` (IN `p_id_bloqueo` INT, IN `p_motivo_levantamiento` TEXT)   BEGIN
    UPDATE `bloqueos_seguridad` 
    SET 
        `estado` = 'LEVANTADO',
        `fecha_hora_desbloqueo` = NOW(),
        `motivo` = CONCAT(`motivo`, ' | Levantado: ', p_motivo_levantamiento)
    WHERE `id_bloqueo` = p_id_bloqueo;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_alerta` (IN `p_nombre_evento` VARCHAR(100), IN `p_descripcion` TEXT, IN `p_umbral` VARCHAR(50), IN `p_severidad` VARCHAR(10), IN `p_detalles` JSON)   BEGIN
    INSERT INTO `eventos_sistema` (
        `tipo_evento`,
        `nombre_evento`,
        `descripcion`,
        `fecha_hora_fin`,
        `estado`,
        `resultado`,
        `detalles`,
        `umbral_alerta`,
        `severidad`
    ) VALUES (
        'ALERTA',
        p_nombre_evento,
        p_descripcion,
        NOW(),
        'COMPLETADO',
        'Alerta generada',
        p_detalles,
        p_umbral,
        p_severidad
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_bloqueo` (IN `p_tipo_bloqueo` VARCHAR(30), IN `p_origen` VARCHAR(20), IN `p_valor_origen` VARCHAR(255), IN `p_motivo` TEXT, IN `p_detalles` JSON, IN `p_severidad` VARCHAR(10), IN `p_accion_tomada` VARCHAR(100), IN `p_id_usuario_relacionado` INT, IN `p_intentos_fallidos` INT, IN `p_umbral_disparador` VARCHAR(50), IN `p_duracion_minutos` INT)   BEGIN
    DECLARE v_fecha_desbloqueo DATETIME;
    
    IF p_duracion_minutos IS NOT NULL THEN
        SET v_fecha_desbloqueo = DATE_ADD(NOW(), INTERVAL p_duracion_minutos MINUTE);
    END IF;
    
    INSERT INTO `bloqueos_seguridad` (
        `tipo_bloqueo`,
        `origen`,
        `valor_origen`,
        `fecha_hora_desbloqueo`,
        `duracion_minutos`,
        `motivo`,
        `detalles`,
        `severidad`,
        `accion_tomada`,
        `id_usuario_relacionado`,
        `intentos_fallidos`,
        `umbral_disparador`
    ) VALUES (
        p_tipo_bloqueo,
        p_origen,
        p_valor_origen,
        v_fecha_desbloqueo,
        p_duracion_minutos,
        p_motivo,
        p_detalles,
        p_severidad,
        p_accion_tomada,
        p_id_usuario_relacionado,
        p_intentos_fallidos,
        p_umbral_disparador
    );
    
    SELECT LAST_INSERT_ID() AS id_bloqueo;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_error` (IN `p_tipo_error` VARCHAR(20), IN `p_codigo_error` VARCHAR(50), IN `p_mensaje` TEXT, IN `p_stack_trace` TEXT, IN `p_estado` VARCHAR(100), IN `p_datos_entrada` JSON, IN `p_id_usuario` INT, IN `p_id_cliente` INT, IN `p_endpoint` VARCHAR(255), IN `p_metodo_http` VARCHAR(10), IN `p_nombre_procedimiento` VARCHAR(100), IN `p_severidad` VARCHAR(10))   BEGIN
    INSERT INTO `registro_errores` (
        `tipo_error`,
        `codigo_error`,
        `mensaje`,
        `stack_trace`,
        `estado`,
        `datos_entrada`,
        `id_usuario`,
        `id_cliente`,
        `endpoint`,
        `metodo_http`,
        `nombre_procedimiento`,
        `severidad`
    ) VALUES (
        p_tipo_error,
        p_codigo_error,
        p_mensaje,
        p_stack_trace,
        p_estado,
        p_datos_entrada,
        p_id_usuario,
        p_id_cliente,
        p_endpoint,
        p_metodo_http,
        p_nombre_procedimiento,
        p_severidad
    );
    
    -- Retornar el ID del error registrado
    SELECT LAST_INSERT_ID() AS id_error;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_verificar_bloqueo` (IN `p_origen` VARCHAR(20), IN `p_valor_origen` VARCHAR(255))   BEGIN
    SELECT * FROM `bloqueos_seguridad`
    WHERE `origen` = p_origen 
      AND `valor_origen` = p_valor_origen
      AND `estado` = 'ACTIVO'
      AND (`fecha_hora_desbloqueo` IS NULL OR `fecha_hora_desbloqueo` > NOW())
    LIMIT 1;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `auditoria`
--

CREATE TABLE `auditoria` (
  `id` int(11) NOT NULL,
  `id_usuario` int(11) DEFAULT NULL,
  `usuario` varchar(50) NOT NULL,
  `tabla_afectada` varchar(50) NOT NULL,
  `accion` varchar(20) NOT NULL,
  `fecha` datetime NOT NULL,
  `es_error` tinyint(1) NOT NULL DEFAULT 0,
  `codigo_error` varchar(50) DEFAULT NULL,
  `stack_trace` text DEFAULT NULL,
  `ip_origen` varchar(45) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Disparadores `auditoria`
--
DELIMITER $$
CREATE TRIGGER `trg_bloquear_intentos_fallidos` AFTER INSERT ON `auditoria` FOR EACH ROW BEGIN
    DECLARE v_intentos_fallidos INT;
    DECLARE v_umbral_bloqueo INT DEFAULT 5;
    DECLARE v_minutos_bloqueo INT DEFAULT 30;
    
    -- Solo actuar en intentos de login fallidos
    IF NEW.`accion` = 'LOGIN_FALLIDO' THEN
        -- Contar intentos fallidos recientes del mismo usuario/IP
        SELECT COUNT(*) INTO v_intentos_fallidos
        FROM `auditoria`
        WHERE (
              (`usuario` = NEW.`usuario` AND NEW.`usuario` IS NOT NULL)
              OR 
              (`ip_origen` = NEW.`ip_origen` AND NEW.`ip_origen` IS NOT NULL)
              )
          AND `accion` = 'LOGIN_FALLIDO'
          AND `fecha` > DATE_SUB(NOW(), INTERVAL 1 HOUR);
        
        -- Verificar si supera el umbral
        IF v_intentos_fallidos >= v_umbral_bloqueo THEN
            -- Determinar origen del bloqueo
            IF NEW.`usuario` IS NOT NULL THEN
                CALL sp_registrar_bloqueo(
                    'INTENTOS_FALLIDOS',
                    'USUARIO',
                    NEW.`usuario`,
                    CONCAT('Bloqueo por ', v_intentos_fallidos, ' intentos fallidos de login'),
                    JSON_OBJECT('intentos', v_intentos_fallidos, 'umbral', v_umbral_bloqueo),
                    'ALTA',
                    'Bloqueo temporal',
                    (SELECT `id_usuario` FROM `usuarios_internos` WHERE `username` = NEW.`usuario` LIMIT 1),
                    v_intentos_fallidos,
                    CONCAT(v_umbral_bloqueo, ' intentos en 1 hora'),
                    v_minutos_bloqueo
                );
            END IF;
            
            -- Bloquear también por IP si está disponible
            IF NEW.`ip_origen` IS NOT NULL THEN
                CALL sp_registrar_bloqueo(
                    'INTENTOS_FALLIDOS',
                    'IP',
                    NEW.`ip_origen`,
                    CONCAT('Bloqueo por ', v_intentos_fallidos, ' intentos fallidos de login desde esta IP'),
                    JSON_OBJECT('intentos', v_intentos_fallidos, 'umbral', v_umbral_bloqueo),
                    'ALTA',
                    'Bloqueo temporal',
                    NULL,
                    v_intentos_fallidos,
                    CONCAT(v_umbral_bloqueo, ' intentos en 1 hora'),
                    v_minutos_bloqueo
                );
            END IF;
        END IF;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `bloqueos_seguridad`
--

CREATE TABLE `bloqueos_seguridad` (
  `id_bloqueo` int(11) NOT NULL,
  `tipo_bloqueo` enum('INTENTOS_FALLIDOS','IP_SOSPECHOSA','COMPORTAMIENTO_ANOMALO','BRUTEFORCE','BLACKLIST','OTRO') NOT NULL,
  `origen` enum('USUARIO','IP','API_KEY','DISPOSITIVO','SISTEMA') NOT NULL,
  `valor_origen` varchar(255) NOT NULL COMMENT 'Usuario, IP, token, etc.',
  `fecha_hora` datetime NOT NULL DEFAULT current_timestamp(),
  `fecha_hora_desbloqueo` datetime DEFAULT NULL,
  `duracion_minutos` int(11) DEFAULT NULL COMMENT 'NULL para bloqueos permanentes',
  `motivo` text NOT NULL,
  `detalles` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`detalles`)),
  `severidad` enum('BAJA','MEDIA','ALTA','CRITICA') NOT NULL DEFAULT 'MEDIA',
  `estado` enum('ACTIVO','LEVANTADO','EXPIRADO') NOT NULL DEFAULT 'ACTIVO',
  `accion_tomada` varchar(100) NOT NULL COMMENT 'Ej: Bloqueo temporal, IP baneada, etc.',
  `id_usuario_relacionado` int(11) DEFAULT NULL,
  `intentos_fallidos` int(11) DEFAULT NULL,
  `umbral_disparador` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categorias_clientes`
--

CREATE TABLE `categorias_clientes` (
  `id_categoria` int(11) NOT NULL,
  `nombre` varchar(20) NOT NULL,
  `descuento` decimal(5,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `categorias_clientes`
--

INSERT INTO `categorias_clientes` (`id_categoria`, `nombre`, `descuento`) VALUES
(1, 'Básico', 0.00),
(2, 'Estándar', 5.00),
(3, 'VIP', 10.00);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `clientes`
--

CREATE TABLE `clientes` (
  `id_cliente` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `categoria_id` int(11) DEFAULT NULL,
  `fecha_registro` date NOT NULL,
  `es_usuario` tinyint(1) NOT NULL DEFAULT 0,
  `password` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `detalles_pedido`
--

CREATE TABLE `detalles_pedido` (
  `id_detalle` int(11) NOT NULL,
  `id_pedido` int(11) NOT NULL,
  `id_producto` int(11) NOT NULL,
  `cantidad` int(11) NOT NULL,
  `precio_unitario` decimal(10,2) NOT NULL,
  `subtotal` decimal(12,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `eventos_sistema`
--

CREATE TABLE `eventos_sistema` (
  `id_evento` int(11) NOT NULL,
  `tipo_evento` enum('BACKUP','LIMPIEZA','ALERTA','MANTENIMIENTO','NOTIFICACION','OTRO') NOT NULL,
  `nombre_evento` varchar(100) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `fecha_hora_inicio` datetime NOT NULL DEFAULT current_timestamp(),
  `fecha_hora_fin` datetime DEFAULT NULL,
  `estado` enum('PENDIENTE','EN_EJECUCION','COMPLETADO','FALLADO','CANCELADO') NOT NULL DEFAULT 'PENDIENTE',
  `resultado` text DEFAULT NULL,
  `detalles` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`detalles`)),
  `duracion_segundos` int(11) DEFAULT NULL,
  `registros_afectados` int(11) DEFAULT NULL,
  `tamano_backup_mb` decimal(10,2) DEFAULT NULL COMMENT 'Solo para eventos de backup',
  `umbral_alerta` varchar(50) DEFAULT NULL COMMENT 'Para eventos de alerta',
  `severidad` enum('INFO','WARNING','ERROR','CRITICAL') DEFAULT 'INFO'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `historial_precios`
--

CREATE TABLE `historial_precios` (
  `id_historial` int(11) NOT NULL,
  `id_producto` int(11) NOT NULL,
  `precio_anterior` decimal(10,2) NOT NULL,
  `precio_nuevo` decimal(10,2) NOT NULL,
  `fecha_cambio` datetime NOT NULL DEFAULT current_timestamp(),
  `tipo_cambio` enum('AJUSTE','OFERTA','INFLACION','COSTO','PROMOCION','OTRO') NOT NULL,
  `motivo` varchar(255) DEFAULT NULL,
  `id_usuario` int(11) DEFAULT NULL COMMENT 'Usuario que realizó el cambio, si aplica',
  `ip_origen` varchar(45) DEFAULT NULL,
  `detalles` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`detalles`)),
  `diferencia` decimal(10,2) GENERATED ALWAYS AS (`precio_nuevo` - `precio_anterior`) STORED,
  `porcentaje_cambio` decimal(5,2) GENERATED ALWAYS AS (case when `precio_anterior` = 0 then 0 else (`precio_nuevo` - `precio_anterior`) / `precio_anterior` * 100 end) STORED
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `pedidos`
--

CREATE TABLE `pedidos` (
  `id_pedido` int(11) NOT NULL,
  `id_cliente` int(11) NOT NULL,
  `fecha` date NOT NULL,
  `total` decimal(12,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `permisos_usuarios`
--

CREATE TABLE `permisos_usuarios` (
  `id_permiso` int(11) NOT NULL,
  `id_usuario` int(11) NOT NULL,
  `modulo` varchar(50) NOT NULL,
  `permiso` enum('lectura','escritura','total') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `productos`
--

CREATE TABLE `productos` (
  `id_producto` int(11) NOT NULL,
  `nombre` varchar(100) NOT NULL,
  `valor_unitario` decimal(10,2) NOT NULL,
  `cantidad_stock` int(11) NOT NULL,
  `fecha_vencimiento` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `productos`
--

INSERT INTO `productos` (`id_producto`, `nombre`, `valor_unitario`, `cantidad_stock`, `fecha_vencimiento`) VALUES
(1, 'arroz', 2000.00, 1, '2025-05-15'),
(2, 'frijoles', 3000.00, 1, '2025-06-11');

--
-- Disparadores `productos`
--
DELIMITER $$
CREATE TRIGGER `trg_registro_cambio_precio` AFTER UPDATE ON `productos` FOR EACH ROW BEGIN
    IF OLD.`valor_unitario` != NEW.`valor_unitario` THEN
        INSERT INTO `historial_precios` (
            `id_producto`,
            `precio_anterior`,
            `precio_nuevo`,
            `tipo_cambio`,
            `id_usuario`,
            `ip_origen`,
            `detalles`
        ) VALUES (
            NEW.`id_producto`,
            OLD.`valor_unitario`,
            NEW.`valor_unitario`,
            'AJUSTE', -- Valor por defecto, puede ser modificado por aplicación
            NULL, -- Se puede obtener de la sesión actual en la aplicación
            NULL, -- Se puede obtener de la conexión en la aplicación
            JSON_OBJECT(
                'usuario_app', CURRENT_USER(),
                'fecha_actualizacion', NOW()
            )
        );
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `registro_errores`
--

CREATE TABLE `registro_errores` (
  `id_error` int(11) NOT NULL,
  `fecha_hora` datetime NOT NULL DEFAULT current_timestamp(),
  `tipo_error` enum('API','PROCEDURE','TRANSACTION','VALIDATION','OTHER') NOT NULL,
  `codigo_error` varchar(50) DEFAULT NULL,
  `mensaje` text NOT NULL,
  `stack_trace` text DEFAULT NULL,
  `estado` varchar(100) DEFAULT NULL,
  `datos_entrada` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`datos_entrada`)),
  `id_usuario` int(11) DEFAULT NULL,
  `id_cliente` int(11) DEFAULT NULL,
  `endpoint` varchar(255) DEFAULT NULL,
  `metodo_http` varchar(10) DEFAULT NULL,
  `nombre_procedimiento` varchar(100) DEFAULT NULL,
  `severidad` enum('INFO','WARNING','ERROR','CRITICAL') NOT NULL DEFAULT 'ERROR',
  `resuelto` tinyint(1) NOT NULL DEFAULT 0,
  `comentario_resolucion` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuarios_internos`
--

CREATE TABLE `usuarios_internos` (
  `id_usuario` int(11) NOT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `nombre_completo` varchar(100) NOT NULL,
  `rol` enum('administrador','operador') NOT NULL,
  `fecha_creacion` datetime NOT NULL DEFAULT current_timestamp(),
  `ultimo_acceso` datetime DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_monitor_bloqueos`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_monitor_bloqueos` (
`id_bloqueo` int(11)
,`tipo_bloqueo` enum('INTENTOS_FALLIDOS','IP_SOSPECHOSA','COMPORTAMIENTO_ANOMALO','BRUTEFORCE','BLACKLIST','OTRO')
,`origen` enum('USUARIO','IP','API_KEY','DISPOSITIVO','SISTEMA')
,`valor_origen` varchar(255)
,`fecha_hora` datetime
,`fecha_hora_desbloqueo` datetime
,`duracion_minutos` int(11)
,`estado` enum('ACTIVO','LEVANTADO','EXPIRADO')
,`severidad` enum('BAJA','MEDIA','ALTA','CRITICA')
,`accion_tomada` varchar(100)
,`intentos_fallidos` int(11)
,`tipo_estado` varchar(10)
,`estado_color` varchar(9)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_monitor_eventos`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_monitor_eventos` (
`id_evento` int(11)
,`tipo_evento` enum('BACKUP','LIMPIEZA','ALERTA','MANTENIMIENTO','NOTIFICACION','OTRO')
,`nombre_evento` varchar(100)
,`fecha_hora_inicio` datetime
,`fecha_hora_fin` datetime
,`estado` enum('PENDIENTE','EN_EJECUCION','COMPLETADO','FALLADO','CANCELADO')
,`duracion_segundos` int(11)
,`registros_afectados` int(11)
,`tamano_backup_mb` decimal(10,2)
,`severidad` enum('INFO','WARNING','ERROR','CRITICAL')
,`estado_color` varchar(7)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `v_reporte_cambios_precio`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `v_reporte_cambios_precio` (
`id_historial` int(11)
,`id_producto` int(11)
,`producto` varchar(100)
,`precio_anterior` decimal(10,2)
,`precio_nuevo` decimal(10,2)
,`diferencia` decimal(10,2)
,`porcentaje_cambio` decimal(5,2)
,`fecha_cambio` datetime
,`tipo_cambio` enum('AJUSTE','OFERTA','INFLACION','COSTO','PROMOCION','OTRO')
,`motivo` varchar(255)
,`usuario` varchar(50)
,`ip_origen` varchar(45)
,`tipo_movimiento` varchar(10)
);

-- --------------------------------------------------------

--
-- Estructura para la vista `v_monitor_bloqueos`
--
DROP TABLE IF EXISTS `v_monitor_bloqueos`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_monitor_bloqueos`  AS SELECT `bloqueos_seguridad`.`id_bloqueo` AS `id_bloqueo`, `bloqueos_seguridad`.`tipo_bloqueo` AS `tipo_bloqueo`, `bloqueos_seguridad`.`origen` AS `origen`, `bloqueos_seguridad`.`valor_origen` AS `valor_origen`, `bloqueos_seguridad`.`fecha_hora` AS `fecha_hora`, `bloqueos_seguridad`.`fecha_hora_desbloqueo` AS `fecha_hora_desbloqueo`, `bloqueos_seguridad`.`duracion_minutos` AS `duracion_minutos`, `bloqueos_seguridad`.`estado` AS `estado`, `bloqueos_seguridad`.`severidad` AS `severidad`, `bloqueos_seguridad`.`accion_tomada` AS `accion_tomada`, `bloqueos_seguridad`.`intentos_fallidos` AS `intentos_fallidos`, CASE WHEN `bloqueos_seguridad`.`estado` = 'ACTIVO' AND `bloqueos_seguridad`.`fecha_hora_desbloqueo` is null THEN 'PERMANENTE' WHEN `bloqueos_seguridad`.`estado` = 'ACTIVO' THEN 'TEMPORAL' ELSE 'INACTIVO' END AS `tipo_estado`, CASE WHEN `bloqueos_seguridad`.`estado` = 'ACTIVO' THEN 'danger' WHEN `bloqueos_seguridad`.`estado` = 'LEVANTADO' THEN 'warning' ELSE 'secondary' END AS `estado_color` FROM `bloqueos_seguridad` ORDER BY `bloqueos_seguridad`.`fecha_hora` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `v_monitor_eventos`
--
DROP TABLE IF EXISTS `v_monitor_eventos`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_monitor_eventos`  AS SELECT `eventos_sistema`.`id_evento` AS `id_evento`, `eventos_sistema`.`tipo_evento` AS `tipo_evento`, `eventos_sistema`.`nombre_evento` AS `nombre_evento`, `eventos_sistema`.`fecha_hora_inicio` AS `fecha_hora_inicio`, `eventos_sistema`.`fecha_hora_fin` AS `fecha_hora_fin`, `eventos_sistema`.`estado` AS `estado`, `eventos_sistema`.`duracion_segundos` AS `duracion_segundos`, `eventos_sistema`.`registros_afectados` AS `registros_afectados`, `eventos_sistema`.`tamano_backup_mb` AS `tamano_backup_mb`, `eventos_sistema`.`severidad` AS `severidad`, CASE WHEN `eventos_sistema`.`estado` = 'COMPLETADO' THEN 'success' WHEN `eventos_sistema`.`estado` = 'FALLADO' THEN 'danger' WHEN `eventos_sistema`.`estado` = 'EN_EJECUCION' THEN 'warning' ELSE 'info' END AS `estado_color` FROM `eventos_sistema` ORDER BY `eventos_sistema`.`fecha_hora_inicio` DESC ;

-- --------------------------------------------------------

--
-- Estructura para la vista `v_reporte_cambios_precio`
--
DROP TABLE IF EXISTS `v_reporte_cambios_precio`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `v_reporte_cambios_precio`  AS SELECT `hp`.`id_historial` AS `id_historial`, `p`.`id_producto` AS `id_producto`, `p`.`nombre` AS `producto`, `hp`.`precio_anterior` AS `precio_anterior`, `hp`.`precio_nuevo` AS `precio_nuevo`, `hp`.`diferencia` AS `diferencia`, `hp`.`porcentaje_cambio` AS `porcentaje_cambio`, `hp`.`fecha_cambio` AS `fecha_cambio`, `hp`.`tipo_cambio` AS `tipo_cambio`, `hp`.`motivo` AS `motivo`, `u`.`username` AS `usuario`, `hp`.`ip_origen` AS `ip_origen`, CASE WHEN `hp`.`precio_nuevo` > `hp`.`precio_anterior` THEN 'AUMENTO' WHEN `hp`.`precio_nuevo` < `hp`.`precio_anterior` THEN 'DESCUENTO' ELSE 'SIN CAMBIO' END AS `tipo_movimiento` FROM ((`historial_precios` `hp` join `productos` `p` on(`hp`.`id_producto` = `p`.`id_producto`)) left join `usuarios_internos` `u` on(`hp`.`id_usuario` = `u`.`id_usuario`)) ORDER BY `hp`.`fecha_cambio` DESC ;

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `auditoria`
--
ALTER TABLE `auditoria`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_auditoria_usuario` (`id_usuario`);

--
-- Indices de la tabla `bloqueos_seguridad`
--
ALTER TABLE `bloqueos_seguridad`
  ADD PRIMARY KEY (`id_bloqueo`),
  ADD KEY `idx_tipo_bloqueo` (`tipo_bloqueo`),
  ADD KEY `idx_origen_valor` (`origen`,`valor_origen`),
  ADD KEY `idx_fecha_hora` (`fecha_hora`),
  ADD KEY `idx_estado` (`estado`),
  ADD KEY `fk_bloqueo_usuario` (`id_usuario_relacionado`);

--
-- Indices de la tabla `categorias_clientes`
--
ALTER TABLE `categorias_clientes`
  ADD PRIMARY KEY (`id_categoria`);

--
-- Indices de la tabla `clientes`
--
ALTER TABLE `clientes`
  ADD PRIMARY KEY (`id_cliente`),
  ADD KEY `fk_cliente_categoria` (`categoria_id`);

--
-- Indices de la tabla `detalles_pedido`
--
ALTER TABLE `detalles_pedido`
  ADD PRIMARY KEY (`id_detalle`),
  ADD KEY `id_pedido` (`id_pedido`),
  ADD KEY `id_producto` (`id_producto`);

--
-- Indices de la tabla `eventos_sistema`
--
ALTER TABLE `eventos_sistema`
  ADD PRIMARY KEY (`id_evento`),
  ADD KEY `idx_tipo_evento` (`tipo_evento`),
  ADD KEY `idx_estado` (`estado`),
  ADD KEY `idx_fecha_hora` (`fecha_hora_inicio`);

--
-- Indices de la tabla `historial_precios`
--
ALTER TABLE `historial_precios`
  ADD PRIMARY KEY (`id_historial`),
  ADD KEY `idx_id_producto` (`id_producto`),
  ADD KEY `idx_fecha_cambio` (`fecha_cambio`),
  ADD KEY `idx_tipo_cambio` (`tipo_cambio`),
  ADD KEY `fk_historial_usuario` (`id_usuario`);

--
-- Indices de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD PRIMARY KEY (`id_pedido`),
  ADD KEY `id_cliente` (`id_cliente`);

--
-- Indices de la tabla `permisos_usuarios`
--
ALTER TABLE `permisos_usuarios`
  ADD PRIMARY KEY (`id_permiso`),
  ADD KEY `id_usuario` (`id_usuario`);

--
-- Indices de la tabla `productos`
--
ALTER TABLE `productos`
  ADD PRIMARY KEY (`id_producto`);

--
-- Indices de la tabla `registro_errores`
--
ALTER TABLE `registro_errores`
  ADD PRIMARY KEY (`id_error`),
  ADD KEY `idx_fecha_hora` (`fecha_hora`),
  ADD KEY `idx_tipo_error` (`tipo_error`),
  ADD KEY `idx_severidad` (`severidad`),
  ADD KEY `idx_resuelto` (`resuelto`),
  ADD KEY `fk_error_usuario` (`id_usuario`),
  ADD KEY `fk_error_cliente` (`id_cliente`);

--
-- Indices de la tabla `usuarios_internos`
--
ALTER TABLE `usuarios_internos`
  ADD PRIMARY KEY (`id_usuario`),
  ADD UNIQUE KEY `username` (`username`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `auditoria`
--
ALTER TABLE `auditoria`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `bloqueos_seguridad`
--
ALTER TABLE `bloqueos_seguridad`
  MODIFY `id_bloqueo` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `categorias_clientes`
--
ALTER TABLE `categorias_clientes`
  MODIFY `id_categoria` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `clientes`
--
ALTER TABLE `clientes`
  MODIFY `id_cliente` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `detalles_pedido`
--
ALTER TABLE `detalles_pedido`
  MODIFY `id_detalle` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `eventos_sistema`
--
ALTER TABLE `eventos_sistema`
  MODIFY `id_evento` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `historial_precios`
--
ALTER TABLE `historial_precios`
  MODIFY `id_historial` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `pedidos`
--
ALTER TABLE `pedidos`
  MODIFY `id_pedido` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `permisos_usuarios`
--
ALTER TABLE `permisos_usuarios`
  MODIFY `id_permiso` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `productos`
--
ALTER TABLE `productos`
  MODIFY `id_producto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT de la tabla `registro_errores`
--
ALTER TABLE `registro_errores`
  MODIFY `id_error` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT de la tabla `usuarios_internos`
--
ALTER TABLE `usuarios_internos`
  MODIFY `id_usuario` int(11) NOT NULL AUTO_INCREMENT;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `auditoria`
--
ALTER TABLE `auditoria`
  ADD CONSTRAINT `fk_auditoria_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios_internos` (`id_usuario`);

--
-- Filtros para la tabla `bloqueos_seguridad`
--
ALTER TABLE `bloqueos_seguridad`
  ADD CONSTRAINT `fk_bloqueo_usuario` FOREIGN KEY (`id_usuario_relacionado`) REFERENCES `usuarios_internos` (`id_usuario`);

--
-- Filtros para la tabla `clientes`
--
ALTER TABLE `clientes`
  ADD CONSTRAINT `fk_cliente_categoria` FOREIGN KEY (`categoria_id`) REFERENCES `categorias_clientes` (`id_categoria`);

--
-- Filtros para la tabla `detalles_pedido`
--
ALTER TABLE `detalles_pedido`
  ADD CONSTRAINT `detalles_pedido_ibfk_1` FOREIGN KEY (`id_pedido`) REFERENCES `pedidos` (`id_pedido`),
  ADD CONSTRAINT `detalles_pedido_ibfk_2` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`);

--
-- Filtros para la tabla `historial_precios`
--
ALTER TABLE `historial_precios`
  ADD CONSTRAINT `fk_historial_producto` FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`),
  ADD CONSTRAINT `fk_historial_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios_internos` (`id_usuario`);

--
-- Filtros para la tabla `pedidos`
--
ALTER TABLE `pedidos`
  ADD CONSTRAINT `pedidos_ibfk_1` FOREIGN KEY (`id_cliente`) REFERENCES `clientes` (`id_cliente`);

--
-- Filtros para la tabla `permisos_usuarios`
--
ALTER TABLE `permisos_usuarios`
  ADD CONSTRAINT `permisos_usuarios_ibfk_1` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios_internos` (`id_usuario`);

--
-- Filtros para la tabla `registro_errores`
--
ALTER TABLE `registro_errores`
  ADD CONSTRAINT `fk_error_cliente` FOREIGN KEY (`id_cliente`) REFERENCES `clientes` (`id_cliente`),
  ADD CONSTRAINT `fk_error_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuarios_internos` (`id_usuario`);

DELIMITER $$
--
-- Eventos
--
CREATE DEFINER=`root`@`localhost` EVENT `evento_limpiar_bloqueos` ON SCHEDULE EVERY 1 HOUR STARTS '2025-04-10 16:15:03' ON COMPLETION NOT PRESERVE ENABLE DO BEGIN
    UPDATE `bloqueos_seguridad`
    SET `estado` = 'EXPIRADO'
    WHERE `estado` = 'ACTIVO'
      AND `fecha_hora_desbloqueo` IS NOT NULL
      AND `fecha_hora_desbloqueo` < NOW();
END$$

DELIMITER ;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
