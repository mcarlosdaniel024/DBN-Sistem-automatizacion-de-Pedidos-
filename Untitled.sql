CREATE TABLE `categorias_clientes` (
  `id_categoria` int PRIMARY KEY AUTO_INCREMENT,
  `descuento` decimal(5,2)
);

CREATE TABLE `clientes` (
  `id_cliente` int PRIMARY KEY AUTO_INCREMENT,
  `nombre` varchar(100),
  `categoria_id` int,
  `fecha_registro` date
);

CREATE TABLE `productos` (
  `id_producto` int PRIMARY KEY AUTO_INCREMENT,
  `nombre` varchar(100),
  `valor_unitario` decimal(10,2),
  `cantidad_stock` int,
  `fecha_vencimiento` date
);

CREATE TABLE `pedidos` (
  `id_pedido` int PRIMARY KEY AUTO_INCREMENT,
  `id_cliente` int,
  `fecha` date,
  `total` decimal(12,2)
);

CREATE TABLE `detalles_pedido` (
  `id_detalle` int PRIMARY KEY AUTO_INCREMENT,
  `id_pedido` int,
  `id_producto` int,
  `cantidad` int,
  `precio_unitario` decimal(10,2),
  `subtotal` decimal(12,2)
);

CREATE TABLE `auditoria` (
  `id` int PRIMARY KEY AUTO_INCREMENT,
  `usuario` varchar(50),
  `tabla_afectada` varchar(50),
  `accion` varchar(20),
  `fecha` datetime
);

ALTER TABLE `clientes` ADD FOREIGN KEY (`categoria_id`) REFERENCES `categorias_clientes` (`id_categoria`);

ALTER TABLE `pedidos` ADD FOREIGN KEY (`id_cliente`) REFERENCES `clientes` (`id_cliente`);

ALTER TABLE `detalles_pedido` ADD FOREIGN KEY (`id_pedido`) REFERENCES `pedidos` (`id_pedido`);

ALTER TABLE `detalles_pedido` ADD FOREIGN KEY (`id_producto`) REFERENCES `productos` (`id_producto`);
