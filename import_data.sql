-- ======================================================
--  IMPORT MASIVO PARA camiones
--  Versión compatible con: psql -f /data/import_data.sql
--  Usa \copy en vez de COPY FROM PROGRAM
--  Convierte "8.0" -> 8
-- ======================================================

\set ON_ERROR_STOP on

BEGIN;

\echo '=== IMPORTACIÓN MASIVA INICIADA ==='
\echo ''

\echo '--- 1) REGIONES ---'
\copy region (nombre, pais) FROM '/data/regiones.csv' DELIMITER ',' CSV HEADER;
SELECT '✓ Regiones cargadas: ' || COUNT(*)::TEXT FROM region;

\echo '--- 2) GERENTES ---'
\copy gerentesucursal (nombre) FROM '/data/gerentes.csv' DELIMITER ',' CSV HEADER;
SELECT '✓ Gerentes cargados: ' || COUNT(*)::TEXT FROM gerentesucursal;

\echo '--- 3) CANALES ---'
\copy canal (nombre) FROM '/data/canales.csv' DELIMITER ',' CSV HEADER;
SELECT '✓ Canales cargados: ' || COUNT(*)::TEXT FROM canal;

\echo '--- 4) CATEGORIAS ---'
\copy productocategoria (nombre_categoria) FROM '/data/categorias.csv' DELIMITER ',' CSV HEADER;
SELECT '✓ Categorías cargadas: ' || COUNT(*)::TEXT FROM productocategoria;

\echo '--- 5) TIPOS DE EJECUTIVO ---'
\copy tipoejecutivo (nombre_tipo) FROM '/data/tipos_ejecutivo.csv' DELIMITER ',' CSV HEADER;
SELECT '✓ Tipos ejecutivo cargados: ' || COUNT(*)::TEXT FROM tipoejecutivo;


-- ======================================================
--  HASTA AQUÍ: TODO LO QUE NO DEPENDE DE NADIE
--  DESDE AQUÍ: VIENEN LOS QUE TIENEN FK
-- ======================================================

\echo ''
\echo '--- 6) SUCURSALES (con staging) ---'
DROP TABLE IF EXISTS staging_sucursales;
CREATE TEMP TABLE staging_sucursales (
    nombre TEXT,
    direccion TEXT,
    id_region TEXT,
    id_gerente TEXT
);

\copy staging_sucursales (nombre, direccion, id_region, id_gerente) FROM '/data/sucursales.csv' DELIMITER ',' CSV HEADER;

INSERT INTO sucursal (nombre, direccion, id_region, id_gerente)
SELECT
    nombre,
    direccion,
    CAST(REPLACE(id_region, '.0', '') AS INT),
    CAST(REPLACE(id_gerente, '.0', '') AS INT)
FROM staging_sucursales
WHERE CAST(REPLACE(id_region, '.0', '') AS INT) IN (SELECT id_region FROM region)
  AND CAST(REPLACE(id_gerente, '.0', '') AS INT) IN (SELECT id_gerente FROM gerentesucursal);

SELECT '✓ Sucursales insertadas: ' || COUNT(*)::TEXT FROM sucursal;

\echo '--- 7) EJECUTIVOS (con staging) ---'
DROP TABLE IF EXISTS staging_ejecutivos;
CREATE TEMP TABLE staging_ejecutivos (
    nombre TEXT,
    rut TEXT,
    id_tipo TEXT,
    id_sucursal TEXT
);

\copy staging_ejecutivos (nombre, rut, id_tipo, id_sucursal) FROM '/data/ejecutivos.csv' DELIMITER ',' CSV HEADER;

INSERT INTO ejecutivo (nombre, rut, id_tipo, id_sucursal)
SELECT
    nombre,
    rut,
    CAST(REPLACE(id_tipo, '.0', '') AS INT),
    CAST(REPLACE(id_sucursal, '.0', '') AS INT)
FROM staging_ejecutivos
WHERE CAST(REPLACE(id_tipo, '.0', '') AS INT) IN (SELECT id_tipo FROM tipoejecutivo)
  AND CAST(REPLACE(id_sucursal, '.0', '') AS INT) IN (SELECT id_sucursal FROM sucursal);

SELECT '✓ Ejecutivos insertados: ' || COUNT(*)::TEXT FROM ejecutivo;

\echo '--- 8) CLIENTES (con staging) ---'
DROP TABLE IF EXISTS staging_clientes;
CREATE TEMP TABLE staging_clientes (
    nombre TEXT,
    rut TEXT,
    id_ejecutivo TEXT
);

\copy staging_clientes (nombre, rut, id_ejecutivo) FROM '/data/clientes.csv' DELIMITER ',' CSV HEADER;

INSERT INTO cliente (nombre, rut, id_ejecutivo)
SELECT
    nombre,
    rut,
    CASE 
        WHEN id_ejecutivo IS NULL OR TRIM(id_ejecutivo) = '' THEN NULL
        ELSE CAST(REPLACE(id_ejecutivo, '.0', '') AS INT)
    END
FROM staging_clientes
WHERE TRIM(nombre) <> '' AND TRIM(rut) <> ''
  AND (id_ejecutivo IS NULL 
       OR TRIM(id_ejecutivo) = '' 
       OR CAST(REPLACE(id_ejecutivo, '.0', '') AS INT) IN (SELECT id_ejecutivo FROM ejecutivo));

SELECT '✓ Clientes insertados: ' || COUNT(*)::TEXT FROM cliente;

\echo '--- 9) PRODUCTOS (con staging) ---'
DROP TABLE IF EXISTS staging_productos;
CREATE TEMP TABLE staging_productos (
    nombre_producto TEXT,
    id_categoria TEXT
);

\copy staging_productos (nombre_producto, id_categoria) FROM '/data/productos.csv' DELIMITER ',' CSV HEADER;

INSERT INTO producto (nombre_producto, id_categoria)
SELECT
    nombre_producto,
    CAST(REPLACE(id_categoria, '.0', '') AS INT)
FROM staging_productos
WHERE CAST(REPLACE(id_categoria, '.0', '') AS INT) IN (SELECT id_categoria FROM productocategoria);

SELECT '✓ Productos insertados: ' || COUNT(*)::TEXT FROM producto;

-- ======================================================
--  HASTA AQUÍ deberías ya tener:
--  region: 16
--  gerentesucursal: 5
--  canal: 3
--  productocategoria: 4
--  tipoejecutivo: 3
--  sucursal: 30
--  ejecutivo: 50
--  cliente: 50
--  producto: 20
-- ======================================================

\echo ''
\echo '--- 10) METAS (usa nombres) ---'
DROP TABLE IF EXISTS staging_metas;
CREATE TEMP TABLE staging_metas (
    periodo_inicio DATE,
    periodo_fin DATE,
    cantidad_meta INT,
    monto_meta NUMERIC(12,2),
    peso_ponderado NUMERIC(5,2),
    ejecutivo TEXT,
    categoria TEXT
);

\copy staging_metas (periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, ejecutivo, categoria) FROM '/data/metas.csv' DELIMITER ',' CSV HEADER;

INSERT INTO meta (
    periodo_inicio, periodo_fin,
    cantidad_meta, monto_meta, peso_ponderado,
    id_ejecutivo, id_categoria
)
SELECT
    s.periodo_inicio,
    s.periodo_fin,
    s.cantidad_meta,
    s.monto_meta,
    s.peso_ponderado,
    e.id_ejecutivo,
    c.id_categoria
FROM staging_metas s
LEFT JOIN ejecutivo e
    ON LOWER(TRIM(e.nombre)) = LOWER(TRIM(s.ejecutivo))
LEFT JOIN productocategoria c
    ON LOWER(TRIM(c.nombre_categoria)) = LOWER(TRIM(s.categoria))
WHERE e.id_ejecutivo IS NOT NULL
  AND c.id_categoria IS NOT NULL
  AND s.periodo_fin > s.periodo_inicio;

SELECT '✓ Metas insertadas: ' || COUNT(*)::TEXT FROM meta;

\echo '--- 11) VENTAS (usa nombres) ---'
DROP TABLE IF EXISTS staging_ventas;
CREATE TEMP TABLE staging_ventas (
    fecha DATE,
    monto NUMERIC(12,2),
    cliente TEXT,
    producto TEXT,
    ejecutivo TEXT,
    canal TEXT
);

\copy staging_ventas (fecha, monto, cliente, producto, ejecutivo, canal) FROM '/data/ventas.csv' DELIMITER ',' CSV HEADER;

INSERT INTO venta (fecha, monto, id_cliente, id_producto, id_ejecutivo, id_canal)
SELECT
    s.fecha,
    s.monto,
    c.id_cliente,
    p.id_producto,
    e.id_ejecutivo,
    ca.id_canal
FROM staging_ventas s
LEFT JOIN cliente c   ON LOWER(TRIM(c.nombre)) = LOWER(TRIM(s.cliente))
LEFT JOIN producto p  ON LOWER(TRIM(p.nombre_producto)) = LOWER(TRIM(s.producto))
LEFT JOIN ejecutivo e ON LOWER(TRIM(e.nombre)) = LOWER(TRIM(s.ejecutivo))
LEFT JOIN canal ca    ON LOWER(TRIM(ca.nombre)) = LOWER(TRIM(s.canal))
WHERE c.id_cliente IS NOT NULL
  AND p.id_producto IS NOT NULL
  AND e.id_ejecutivo IS NOT NULL
  AND ca.id_canal IS NOT NULL;

SELECT '✓ Ventas insertadas: ' || COUNT(*)::TEXT FROM venta;

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
\echo '✅ Importación completada con éxito ✅'
