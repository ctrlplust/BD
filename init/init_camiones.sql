-- =====================================================
--   SCRIPT DE INICIALIZACIÓN: init_banco.sql
--   Base de datos: camiones
--   Contexto: Banco Futura - Metas y Ventas simuladas
--   Nota mía: este script amplía datos para tests
--             más realistas (otras regiones/sucursales).
-- =====================================================

BEGIN;

-- ===========================================
-- 1) Regiones y Sucursales adicionales
--    Nota: agrego 2 regiones y sus sucursales.
-- ===========================================

INSERT INTO region (nombre, pais)
VALUES 
    ('Valparaíso', 'Chile'),
    ('Biobío', 'Chile');

INSERT INTO GerenteSucursal (nombre)
VALUES 
    ('Gerente 2'),
    ('Gerente 3');

INSERT INTO Sucursal (nombre, direccion, id_region, id_gerente)
VALUES
    ('Sucursal Viña del Mar', 'Av. Libertad 450', 2, 2),
    ('Sucursal Concepción', 'Av. Los Carrera 1500', 3, 3);

-- ===========================================
-- 2) Ejecutivos y Clientes nuevos
--    Nota: un cliente queda “independiente” (sin ejecutivo).
-- ===========================================

INSERT INTO Ejecutivo (nombre, rut, id_tipo, id_sucursal)
VALUES 
    ('Carlos Soto', '13.456.789-0', 2, 2),
    ('María López', '11.223.344-5', 3, 3);

INSERT INTO Cliente (nombre, rut, id_ejecutivo)
VALUES 
    ('Cliente Viña', '7.654.321-0', 2),
    ('Cliente Concepción', '8.765.432-1', 3),
    ('Cliente Independiente', '6.543.210-9', NULL);

-- ===========================================
-- 3) Productos adicionales (nueva categoría)
--    Nota: agrego “Inversiones” y dos productos.
-- ===========================================

INSERT INTO ProductoCategoria (nombre_categoria)
VALUES ('Inversiones');

INSERT INTO Producto (nombre_producto, id_categoria)
VALUES 
    ('Cuenta Corriente Premium', 3),
    ('Fondo Mutuo Futuro', 4);

-- ===========================================
-- 4) Ventas de ejemplo (fechas septiembre)
--    Nota: cubro distintos ejecutivos y categorías.
-- ===========================================

INSERT INTO Venta (fecha, monto, id_cliente, id_producto, id_ejecutivo)
VALUES
    ('2025-09-10', 250000, 2, 3, 2),
    ('2025-09-15', 400000, 3, 4, 3),
    ('2025-09-18', 150000, 1, 1, 1);

-- ===========================================
-- 5) Metas por categoría (octubre)
--    Nota: metas distintas por ejecutivo/categoría.
-- ===========================================

INSERT INTO Meta (periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria)
VALUES
    ('2025-10-01', '2025-10-31', 15, 2000000, 70.00, 2, 2),
    ('2025-10-01', '2025-10-31', 20, 1500000, 50.00, 3, 4);

COMMIT;
