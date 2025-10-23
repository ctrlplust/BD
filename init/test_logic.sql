-- =========================================================
-- test_logic.sql · Batería mínima de pruebas de lógica (sin DO)
-- =========================================================

-- Contexto
SELECT current_date AS hoy, current_user AS usuario, current_schema AS esquema;

-- 1) Precondiciones mínimas
DO $$
BEGIN
  PERFORM 1 FROM pg_class WHERE relname IN ('meta','venta','producto','cliente');
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Faltan tablas base (meta/venta/producto/cliente). Corre init_camiones.sql primero.';
  END IF;
END$$;

-- 2) Asegurar datos base mínimos y capturar variables
-- categoría "Tarjetas" (o la primera que exista)
WITH c AS (
  SELECT id_categoria FROM ProductoCategoria WHERE nombre_categoria = 'Tarjetas'
)
SELECT COALESCE((SELECT id_categoria FROM c),
                (SELECT id_categoria FROM ProductoCategoria LIMIT 1)) AS cat_tarjetas
\gset

-- producto de esa categoría (si no hay, creo uno temporal)
WITH p AS (
  SELECT id_producto FROM Producto WHERE id_categoria = :cat_tarjetas LIMIT 1
), ins AS (
  INSERT INTO Producto(nombre_producto, id_categoria)
  SELECT 'Producto Test Tarjetas', :cat_tarjetas
  WHERE NOT EXISTS (SELECT 1 FROM p)
  RETURNING id_producto
)
SELECT COALESCE((SELECT id_producto FROM p),
                (SELECT id_producto FROM ins)) AS test_id_producto
\gset

-- ejecutivo (1 si existe, si no el primero)
SELECT COALESCE(
  (SELECT id_ejecutivo FROM Ejecutivo WHERE id_ejecutivo = 1),
  (SELECT id_ejecutivo FROM Ejecutivo LIMIT 1)
) AS test_id_ejecutivo
\gset

-- cliente (si no hay, creo uno y lo asigno al ejecutivo elegido)
WITH c AS (
  SELECT id_cliente FROM Cliente LIMIT 1
), ins AS (
  INSERT INTO Cliente(nombre, rut, id_ejecutivo)
  SELECT 'Cliente Test', '99.999.999-9', :test_id_ejecutivo
  WHERE NOT EXISTS (SELECT 1 FROM c)
  RETURNING id_cliente
)
SELECT COALESCE((SELECT id_cliente FROM c),
                (SELECT id_cliente FROM ins)) AS test_id_cliente
\gset

-- asegurar consistencia cliente-ejecutivo
UPDATE Cliente
SET id_ejecutivo = :test_id_ejecutivo
WHERE id_cliente = :test_id_cliente;

-- 3) sp_definir_meta + trigger de solape (bordes cerrados)
-- 3.1 OK: crear meta base
SELECT sp_definir_meta(:test_id_ejecutivo, :cat_tarjetas,
                       DATE '2025-10-01', DATE '2025-10-31',
                       10, 1000000, 60) AS id_meta_ok
\gset

-- 3.2 DEBE FALLAR: solape claro
\set ON_ERROR_STOP 0
SELECT sp_definir_meta(:test_id_ejecutivo, :cat_tarjetas,
                       DATE '2025-10-15', DATE '2025-11-15',
                       5, 500000, 40);
\set ON_ERROR_STOP 1

-- 3.3 DEBE FALLAR: borde compartido (31) también cuenta como solape
\set ON_ERROR_STOP 0
SELECT sp_definir_meta(:test_id_ejecutivo, :cat_tarjetas,
                       DATE '2025-10-31', DATE '2025-11-30',
                       5, 500000, 40);
\set ON_ERROR_STOP 1

-- 4) sp_registrar_venta + trigger de validación
-- 4.1 OK: venta dentro del período (debe pasar)
SELECT sp_registrar_venta(DATE '2025-10-10', 250000,
                          :test_id_cliente, :test_id_producto, :test_id_ejecutivo)
      AS id_venta_ok
\gset

-- 4.2 DEBE FALLAR: cliente asignado a otro ejecutivo
\set ON_ERROR_STOP 0
WITH otro AS (
  SELECT id_ejecutivo FROM Ejecutivo
  WHERE id_ejecutivo <> :test_id_ejecutivo LIMIT 1
)
SELECT sp_registrar_venta(DATE '2025-10-12', 100000,
                          :test_id_cliente, :test_id_producto, (SELECT id_ejecutivo FROM otro));
\set ON_ERROR_STOP 1

-- 4.3 DEBE FALLAR: venta fuera del período de meta
\set ON_ERROR_STOP 0
SELECT sp_registrar_venta(DATE '2025-09-01', 50000,
                          :test_id_cliente, :test_id_producto, :test_id_ejecutivo);
\set ON_ERROR_STOP 1

-- 5) Vista de avance
SELECT * FROM vw_metas_con_avance WHERE id_meta = :id_meta_ok;

-- 6) Borrar la venta y verificar recálculo
DELETE FROM venta WHERE id_venta = :id_venta_ok;
SELECT * FROM vw_metas_con_avance WHERE id_meta = :id_meta_ok;

-- 7) Limpieza mínima de datos temporales
DELETE FROM Producto WHERE nombre_producto = 'Producto Test Tarjetas';
DELETE FROM Cliente  WHERE nombre = 'Cliente Test' AND rut = '99.999.999-9';
