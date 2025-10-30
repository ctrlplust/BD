-- =====================================================
--   import_data.sql (versión psql dentro de Docker)
--   Ejecutar con:  \i /data/import_data.sql
--   Requiere que existan las tablas
-- =====================================================

\echo '--- Importando REGIONES ---'
\copy region (nombre, pais) FROM '/data/regiones.csv' DELIMITER ',' CSV HEADER;

\echo '--- Importando GERENTES ---'
\copy gerentesucursal (nombre) FROM '/data/gerentes.csv' DELIMITER ',' CSV HEADER;

\echo '--- Importando CANALES ---'
\copy canal (nombre) FROM '/data/canales.csv' DELIMITER ',' CSV HEADER;

\echo '--- Importando CATEGORIAS ---'
\copy productocategoria (nombre_categoria) FROM '/data/categorias.csv' DELIMITER ',' CSV HEADER;

\echo '--- Importando TIPOS DE EJECUTIVO ---'
\copy tipoejecutivo (nombre_tipo) FROM '/data/tipos_ejecutivo.csv' DELIMITER ',' CSV HEADER;

-- ============================
-- SUCURSALES (usa staging)
-- ============================
\echo '--- Creando staging_sucursales ---'
DROP TABLE IF EXISTS staging_sucursales;
CREATE TEMP TABLE staging_sucursales (
    nombre TEXT,
    direccion TEXT,
    region TEXT,
    gerente TEXT
);

\echo '--- Cargando staging_sucursales ---'
\copy staging_sucursales (nombre, direccion, region, gerente) FROM '/data/sucursales.csv' DELIMITER ',' CSV HEADER;

\echo '--- Insertando en SUCURSAL ---'
INSERT INTO sucursal (nombre, direccion, id_region, id_gerente)
SELECT
    s.nombre,
    s.direccion,
    r.id_region,
    g.id_gerente
FROM staging_sucursales s
JOIN region r ON r.nombre = s.region
JOIN gerentesucursal g ON g.nombre = s.gerente
ON CONFLICT (nombre, id_region) DO NOTHING;

-- ============================
-- EJECUTIVOS (usa staging)
-- ============================
\echo '--- Creando staging_ejecutivos ---'
DROP TABLE IF EXISTS staging_ejecutivos;
CREATE TEMP TABLE staging_ejecutivos (
    nombre TEXT,
    rut TEXT,
    tipo TEXT,
    sucursal TEXT
);

\echo '--- Cargando staging_ejecutivos ---'
\copy staging_ejecutivos (nombre, rut, tipo, sucursal) FROM '/data/ejecutivos.csv' DELIMITER ',' CSV HEADER;

\echo '--- Insertando en EJECUTIVO ---'
INSERT INTO ejecutivo (nombre, rut, id_tipo, id_sucursal)
SELECT
    s.nombre,
    s.rut,
    t.id_tipo,
    su.id_sucursal
FROM staging_ejecutivos s
JOIN tipoejecutivo t ON t.nombre_tipo = s.tipo
JOIN sucursal su ON su.nombre = s.sucursal
ON CONFLICT (rut) DO NOTHING;

-- ============================
-- CLIENTES (usa staging)
-- ============================
\echo '--- Creando staging_clientes ---'
DROP TABLE IF EXISTS staging_clientes;
CREATE TEMP TABLE staging_clientes (
    nombre TEXT,
    rut TEXT,
    ejecutivo TEXT
);

\echo '--- Cargando staging_clientes ---'
\copy staging_clientes (nombre, rut, ejecutivo) FROM '/data/clientes.csv' DELIMITER ',' CSV HEADER;

\echo '--- Insertando en CLIENTE ---'
INSERT INTO cliente (nombre, rut, id_ejecutivo)
SELECT
    s.nombre,
    s.rut,
    CASE
        WHEN s.ejecutivo IS NULL OR s.ejecutivo = '' THEN NULL
        ELSE (SELECT e.id_ejecutivo FROM ejecutivo e WHERE e.nombre = s.ejecutivo)
    END
FROM staging_clientes s
ON CONFLICT (rut) DO NOTHING;

-- ============================
-- PRODUCTOS (usa staging)
-- ============================
\echo '--- Creando staging_productos ---'
DROP TABLE IF EXISTS staging_productos;
CREATE TEMP TABLE staging_productos (
    nombre_producto TEXT,
    categoria TEXT
);

\echo '--- Cargando staging_productos ---'
\copy staging_productos (nombre_producto, categoria) FROM '/data/productos.csv' DELIMITER ',' CSV HEADER;

\echo '--- Insertando en PRODUCTO ---'
INSERT INTO producto (nombre_producto, id_categoria)
SELECT
    s.nombre_producto,
    c.id_categoria
FROM staging_productos s
JOIN productocategoria c ON c.nombre_categoria = s.categoria
ON CONFLICT (nombre_producto) DO NOTHING;

-- ============================
-- METAS (usa staging)
-- ============================
\echo '--- Creando staging_metas ---'
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

\echo '--- Cargando staging_metas ---'
\copy staging_metas (periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, ejecutivo, categoria)
FROM '/data/metas.csv' DELIMITER ',' CSV HEADER;

\echo '--- Insertando en META ---'
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
JOIN ejecutivo e ON e.nombre = s.ejecutivo
JOIN productocategoria c ON c.nombre_categoria = s.categoria
ON CONFLICT DO NOTHING;

-- ============================
-- VENTAS (usa staging)
-- ============================
\echo '--- Creando staging_ventas ---'
DROP TABLE IF EXISTS staging_ventas;
CREATE TEMP TABLE staging_ventas (
    fecha DATE,
    monto NUMERIC(12,2),
    cliente TEXT,
    producto TEXT,
    ejecutivo TEXT,
    canal TEXT
);

\echo '--- Cargando staging_ventas ---'
\copy staging_ventas (fecha, monto, cliente, producto, ejecutivo, canal)
FROM '/data/ventas.csv' DELIMITER ',' CSV HEADER;

\echo '--- Insertando en VENTA ---'
INSERT INTO venta (fecha, monto, id_cliente, id_producto, id_ejecutivo, id_canal)
SELECT
    s.fecha,
    s.monto,
    c.id_cliente,
    p.id_producto,
    e.id_ejecutivo,
    ca.id_canal
FROM staging_ventas s
JOIN cliente c   ON c.nombre = s.cliente
JOIN producto p  ON p.nombre_producto = s.producto
JOIN ejecutivo e ON e.nombre = s.ejecutivo
JOIN canal ca    ON ca.nombre = s.canal;

\echo '--- Importación terminada ---'
