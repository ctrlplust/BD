-- =====================================================
--  SCRIPT DE RESET E IMPORTACIÓN COMPLETA
--  Ejecutar con: docker exec -it camiones_db psql -U postgres -d camiones -f /data/reset_and_import.sql
-- =====================================================

\set ON_ERROR_STOP on

BEGIN;

\echo '=== LIMPIEZA DE TABLAS ==='
-- 1. Limpiar todas las tablas en orden correcto
TRUNCATE TABLE venta CASCADE;
TRUNCATE TABLE meta CASCADE;
TRUNCATE TABLE cliente CASCADE;
TRUNCATE TABLE producto CASCADE;
TRUNCATE TABLE ejecutivo CASCADE;
TRUNCATE TABLE sucursal CASCADE;
TRUNCATE TABLE region CASCADE;
TRUNCATE TABLE gerentesucursal CASCADE;
TRUNCATE TABLE canal CASCADE;
TRUNCATE TABLE productocategoria CASCADE;
TRUNCATE TABLE tipoejecutivo CASCADE;

-- 2. Resetear todas las secuencias
ALTER SEQUENCE region_id_region_seq RESTART WITH 1;
ALTER SEQUENCE gerentesucursal_id_gerente_seq RESTART WITH 1;
ALTER SEQUENCE canal_id_canal_seq RESTART WITH 1;
ALTER SEQUENCE productocategoria_id_categoria_seq RESTART WITH 1;
ALTER SEQUENCE tipoejecutivo_id_tipo_seq RESTART WITH 1;
ALTER SEQUENCE sucursal_id_sucursal_seq RESTART WITH 1;
ALTER SEQUENCE ejecutivo_id_ejecutivo_seq RESTART WITH 1;
ALTER SEQUENCE cliente_id_cliente_seq RESTART WITH 1;
ALTER SEQUENCE producto_id_producto_seq RESTART WITH 1;
ALTER SEQUENCE meta_id_meta_seq RESTART WITH 1;
ALTER SEQUENCE venta_id_venta_seq RESTART WITH 1;

\echo '=== IMPORTACIÓN DE TABLAS BASE ==='
-- 3. Cargar tablas base
\echo '--- Regiones ---'
\copy region (nombre, pais) FROM '/data/regiones.csv' DELIMITER ',' CSV HEADER;
SELECT setval('region_id_region_seq', (SELECT MAX(id_region) FROM region));

\echo '--- Gerentes ---'
\copy gerentesucursal (nombre) FROM '/data/gerentes.csv' DELIMITER ',' CSV HEADER;
SELECT setval('gerentesucursal_id_gerente_seq', (SELECT MAX(id_gerente) FROM gerentesucursal));

\echo '--- Canales ---'
\copy canal (nombre) FROM '/data/canales.csv' DELIMITER ',' CSV HEADER;

\echo '--- Categorías ---'
\copy productocategoria (nombre_categoria) FROM '/data/categorias.csv' DELIMITER ',' CSV HEADER;

\echo '--- Tipos de Ejecutivo ---'
\copy tipoejecutivo (nombre_tipo) FROM '/data/tipos_ejecutivo.csv' DELIMITER ',' CSV HEADER;

\echo '=== IMPORTACIÓN DE TABLAS DEPENDIENTES ==='
-- 4. Importar sucursales
\echo '--- Sucursales ---'
DROP TABLE IF EXISTS staging_sucursales;
CREATE TEMP TABLE staging_sucursales (
    nombre TEXT,
    direccion TEXT,
    id_region TEXT,
    id_gerente TEXT
);

\copy staging_sucursales FROM '/data/sucursales.csv' DELIMITER ',' CSV HEADER;

INSERT INTO sucursal (nombre, direccion, id_region, id_gerente)
SELECT
    nombre,
    direccion,
    CAST(REPLACE(id_region, '.0', '') AS INT),
    CAST(REPLACE(id_gerente, '.0', '') AS INT)
FROM staging_sucursales;

-- 5. Importar ejecutivos
\echo '--- Ejecutivos ---'
DROP TABLE IF EXISTS staging_ejecutivos;
CREATE TEMP TABLE staging_ejecutivos (
    nombre TEXT,
    rut TEXT,
    id_tipo TEXT,
    id_sucursal TEXT
);

\copy staging_ejecutivos FROM '/data/ejecutivos.csv' DELIMITER ',' CSV HEADER;

INSERT INTO ejecutivo (nombre, rut, id_tipo, id_sucursal)
SELECT
    nombre,
    rut,
    CAST(REPLACE(id_tipo, '.0', '') AS INT),
    CAST(REPLACE(id_sucursal, '.0', '') AS INT)
FROM staging_ejecutivos;

-- 6. Importar productos
\echo '--- Productos ---'
DROP TABLE IF EXISTS staging_productos;
CREATE TEMP TABLE staging_productos (
    nombre_producto TEXT,
    id_categoria TEXT
);

\copy staging_productos FROM '/data/productos.csv' DELIMITER ',' CSV HEADER;

INSERT INTO producto (nombre_producto, id_categoria)
SELECT
    nombre_producto,
    CAST(REPLACE(id_categoria, '.0', '') AS INT)
FROM staging_productos;

-- 7. Importar clientes
\echo '--- Clientes ---'
DROP TABLE IF EXISTS staging_clientes;
CREATE TEMP TABLE staging_clientes (
    nombre TEXT,
    rut TEXT,
    id_ejecutivo TEXT
);

\copy staging_clientes FROM '/data/clientes.csv' DELIMITER ',' CSV HEADER;

INSERT INTO cliente (nombre, rut)
SELECT 
    nombre,
    rut
FROM staging_clientes;

-- 8. Crear mapeos para ventas
\echo '--- Creando mapeos ---'
DROP TABLE IF EXISTS mapeo_clientes;
DROP TABLE IF EXISTS mapeo_productos;
DROP TABLE IF EXISTS mapeo_ejecutivos;
DROP TABLE IF EXISTS mapeo_canales;

CREATE TEMP TABLE mapeo_ejecutivos (
    nombre_csv TEXT,
    id_ejecutivo INT
);

-- Cambio: Usar números directamente para los ejecutivos
INSERT INTO mapeo_ejecutivos VALUES
('1', 1),      -- Ejecutivo 1
('2', 2),      -- Ejecutivo 2
('3', 3);      -- Ejecutivo 3

CREATE TEMP TABLE mapeo_clientes AS
SELECT DISTINCT c.id_cliente, c.nombre as nombre_csv
FROM cliente c;

CREATE TEMP TABLE mapeo_productos AS
SELECT DISTINCT p.id_producto, p.nombre_producto as nombre_csv
FROM producto p;

CREATE TEMP TABLE mapeo_canales (
    nombre_csv TEXT,
    id_canal INT
);

INSERT INTO mapeo_canales VALUES
('Mesón', 1),      -- Sucursal
('Web', 2),        -- Digital
('App', 2),        -- Digital
('Call Center', 3);

-- 9. Generar metas para todos los ejecutivos y categorías
\echo '--- Metas ---'
INSERT INTO meta (periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria)
SELECT
    periodo::date as periodo_inicio,
    (periodo + interval '1 month' - interval '1 day')::date as periodo_fin,
    10 as cantidad_meta,
    1500000 as monto_meta,
    60 as peso_ponderado,
    e.id_ejecutivo,
    c.id_categoria
FROM (VALUES 
    ('2025-09-01'::date),
    ('2025-10-01'::date)
) as dates(periodo)
CROSS JOIN (SELECT id_ejecutivo FROM ejecutivo WHERE id_ejecutivo IN (1,2,3)) e
CROSS JOIN (SELECT id_categoria FROM productocategoria WHERE id_categoria IN (1,2,3,4)) c;

-- 10. Importar ventas
\echo '--- Ventas ---'
DROP TABLE IF EXISTS staging_ventas;
CREATE TEMP TABLE staging_ventas (
    fecha TEXT,
    monto TEXT,
    cliente TEXT,
    producto TEXT,
    ejecutivo TEXT,
    canal TEXT
);

\copy staging_ventas FROM '/data/ventas.csv' DELIMITER ',' CSV HEADER;

-- Mostrar datos originales
\echo '--- Datos originales en staging_ventas ---'
SELECT * FROM staging_ventas;

-- Actualizar nombres en staging para que coincidan con la base de datos
UPDATE staging_ventas 
SET producto = 
    CASE 
        WHEN producto = 'Tarjeta Visa' THEN 'Tarjeta Crédito'
        WHEN producto = 'Fondo Mutuo Futuro' THEN 'Fondo Mutuo'
        ELSE producto
    END;

\echo '--- Después de actualizar productos ---'
SELECT * FROM staging_ventas;

UPDATE staging_ventas 
SET canal = 
    CASE 
        WHEN canal = 'Mesón' THEN 'Sucursal'
        WHEN canal = 'Web' THEN 'Digital'
        WHEN canal = 'App' THEN 'Digital'
    END;

\echo '--- Después de actualizar canales ---'
SELECT * FROM staging_ventas;

UPDATE staging_ventas 
SET cliente = 
    CASE 
        WHEN LOWER(cliente) = LOWER('Cliente demo') THEN 'Cliente 1'
        WHEN LOWER(cliente) = LOWER('Cliente Concepción') THEN 'Cliente 2'
        WHEN LOWER(cliente) = LOWER('Cliente Viña') THEN 'Cliente 3'
    END;

\echo '--- Después de actualizar clientes ---'
SELECT * FROM staging_ventas;

-- Mostrar los mapeos disponibles
\echo '--- Mapeos disponibles ---'
\echo 'Mapeo de productos:'
SELECT * FROM mapeo_productos;
\echo 'Mapeo de clientes:'
SELECT * FROM mapeo_clientes;
\echo 'Mapeo de canales:'
SELECT * FROM mapeo_canales;

-- Insertar ventas desde staging con más detalle en el JOIN
INSERT INTO venta (fecha, monto, id_cliente, id_producto, id_ejecutivo, id_canal)
SELECT 
    v.fecha::date,
    v.monto::numeric,
    mc.id_cliente,
    mp.id_producto,
    CAST(v.ejecutivo AS INT) as id_ejecutivo,
    mca.id_canal
FROM staging_ventas v
LEFT JOIN mapeo_clientes mc ON LOWER(TRIM(mc.nombre_csv)) = LOWER(TRIM(v.cliente))
LEFT JOIN mapeo_productos mp ON LOWER(TRIM(mp.nombre_csv)) = LOWER(TRIM(v.producto))
LEFT JOIN mapeo_canales mca ON LOWER(TRIM(mca.nombre_csv)) = LOWER(TRIM(v.canal))
WHERE mc.id_cliente IS NOT NULL 
  AND mp.id_producto IS NOT NULL 
  AND mca.id_canal IS NOT NULL;

-- 11. Limpiar tablas temporales
DROP TABLE IF EXISTS staging_ventas;
DROP TABLE IF EXISTS staging_sucursales;
DROP TABLE IF EXISTS staging_ejecutivos;
DROP TABLE IF EXISTS staging_productos;
DROP TABLE IF EXISTS staging_clientes;
DROP TABLE IF EXISTS staging_metas;
DROP TABLE IF EXISTS mapeo_clientes;
DROP TABLE IF EXISTS mapeo_productos;
DROP TABLE IF EXISTS mapeo_ejecutivos;
DROP TABLE IF EXISTS mapeo_canales;

-- 12. Mostrar resumen final
\echo ''
\echo '=== RESUMEN FINAL ==='
SELECT 'region' AS tabla, COUNT(*) AS filas FROM region
UNION ALL SELECT 'gerentesucursal', COUNT(*) FROM gerentesucursal
UNION ALL SELECT 'canal', COUNT(*) FROM canal
UNION ALL SELECT 'productocategoria', COUNT(*) FROM productocategoria
UNION ALL SELECT 'tipoejecutivo', COUNT(*) FROM tipoejecutivo
UNION ALL SELECT 'sucursal', COUNT(*) FROM sucursal
UNION ALL SELECT 'ejecutivo', COUNT(*) FROM ejecutivo
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'meta', COUNT(*) FROM meta
UNION ALL SELECT 'venta', COUNT(*) FROM venta
ORDER BY tabla;

COMMIT;

\echo ''
\echo '=== VERIFICACIÓN DE DATOS ==='
-- Verificar los datos cargados
\echo '--- Ventas ---'
SELECT 
    v.fecha,
    v.monto,
    c.nombre as cliente,
    p.nombre_producto as producto,
    e.nombre as ejecutivo,
    ca.nombre as canal
FROM venta v
JOIN cliente c ON c.id_cliente = v.id_cliente
JOIN producto p ON p.id_producto = v.id_producto
JOIN ejecutivo e ON e.id_ejecutivo = v.id_ejecutivo
JOIN canal ca ON ca.id_canal = v.id_canal
ORDER BY v.fecha;

\echo ''
\echo '--- Metas ---'
SELECT 
    periodo_inicio,
    periodo_fin,
    e.nombre as ejecutivo,
    pc.nombre_categoria,
    cantidad_meta,
    monto_meta
FROM meta m
JOIN ejecutivo e ON e.id_ejecutivo = m.id_ejecutivo
JOIN productocategoria pc ON pc.id_categoria = m.id_categoria
ORDER BY periodo_inicio, e.id_ejecutivo, pc.id_categoria;

\echo ''
\echo '--- Vista de Avance ---'
SELECT * FROM vw_metas_con_avance;

\echo ''
\echo '✅ Base de datos reiniciada e importada con éxito'