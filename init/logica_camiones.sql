-- =====================================================
--   LÓGICA DE NEGOCIOS: funciones, triggers, SP, vistas
--   Nota mía: acá vive la “inteligencia” de la BD.
--   Política de solape: BORDES CERRADOS (comparten día = solape)
-- =====================================================

BEGIN;

-- =========================================================
-- 1) HELPERS
--    Nota: funciones chiquitas que reutilizo en triggers/SP.
-- =========================================================

-- Me devuelve la categoría del producto (para mapear Venta -> Meta)
CREATE OR REPLACE FUNCTION fn_categoria_de_producto(p_id_producto INT)
RETURNS INT
LANGUAGE sql STABLE AS $$
  SELECT id_categoria FROM producto WHERE id_producto = p_id_producto
$$;

-- Me dice si dos rangos de fecha se solapan (bordes cerrados)
CREATE OR REPLACE FUNCTION fn_rangos_solapan(a1 DATE, a2 DATE, b1 DATE, b2 DATE)
RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE AS $$
  SELECT NOT (a2 < b1 OR b2 < a1)
$$;

-- =========================================================
-- 2) TRIGGER: impedir metas solapadas (ejecutivo, categoría)
--    Nota: corre BEFORE I/U y bloquea si choca con otra meta.
-- =========================================================

CREATE OR REPLACE FUNCTION trg_meta_no_solape_fn()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
  v_conflicto INT;
BEGIN
  SELECT 1 INTO v_conflicto
  FROM meta m
  WHERE m.id_ejecutivo = NEW.id_ejecutivo
    AND m.id_categoria  = NEW.id_categoria
    AND fn_rangos_solapan(m.periodo_inicio, m.periodo_fin, NEW.periodo_inicio, NEW.periodo_fin)
    AND (
         (TG_OP = 'UPDATE' AND m.id_meta <> NEW.id_meta)  -- Nota: me excluyo si estoy editando.
      OR (TG_OP = 'INSERT')
    )
  LIMIT 1;

  IF v_conflicto = 1 THEN
    RAISE EXCEPTION 'Meta solapada para ejecutivo % y categoría % en [% - %]',
      NEW.id_ejecutivo, NEW.id_categoria, NEW.periodo_inicio, NEW.periodo_fin
      USING ERRCODE = 'unique_violation';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_meta_no_solape ON meta;
CREATE TRIGGER trg_meta_no_solape
BEFORE INSERT OR UPDATE ON meta
FOR EACH ROW EXECUTE FUNCTION trg_meta_no_solape_fn();

-- =========================================================
-- 3) TRIGGER: validar ventas (consistencia y meta vigente)
--    Regla 1: si el cliente tiene ejecutivo asignado, debe coincidir.
--    Regla 2: debe existir meta vigente para (ejecutivo, categoría).
-- =========================================================

CREATE OR REPLACE FUNCTION trg_venta_validar_fn()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
  v_ejec_cliente INT;
  v_categoria    INT;
  v_meta_ok      INT;
BEGIN
  -- (1) Consistencia cliente-ejecutivo
  SELECT id_ejecutivo INTO v_ejec_cliente
  FROM cliente
  WHERE id_cliente = NEW.id_cliente;

  IF v_ejec_cliente IS NOT NULL AND v_ejec_cliente <> NEW.id_ejecutivo THEN
    RAISE EXCEPTION 'El cliente % está asignado al ejecutivo %, no al %',
      NEW.id_cliente, v_ejec_cliente, NEW.id_ejecutivo
      USING ERRCODE = 'check_violation';
  END IF;

  -- (2) Meta vigente por categoría del producto
  SELECT fn_categoria_de_producto(NEW.id_producto) INTO v_categoria;
  IF v_categoria IS NULL THEN
    RAISE EXCEPTION 'Producto % no existe o no tiene categoría', NEW.id_producto
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  SELECT 1 INTO v_meta_ok
  FROM meta
  WHERE id_ejecutivo = NEW.id_ejecutivo
    AND id_categoria  = v_categoria
    AND NEW.fecha BETWEEN periodo_inicio AND periodo_fin
  LIMIT 1;

  IF v_meta_ok IS DISTINCT FROM 1 THEN
    RAISE EXCEPTION 'No hay meta vigente para ejecutivo % y categoría % en la fecha %',
      NEW.id_ejecutivo, v_categoria, NEW.fecha
      USING ERRCODE = 'check_violation';
  END IF;

  -- (3) Normalizo el monto a 2 decimales (por prolijidad)
  NEW.monto := ROUND(NEW.monto::numeric, 2);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_venta_validar ON venta;
CREATE TRIGGER trg_venta_validar
BEFORE INSERT OR UPDATE ON venta
FOR EACH ROW EXECUTE FUNCTION trg_venta_validar_fn();

-- =========================================================
-- 4) TABLA CACHE: CumplimientoMeta
--    Nota: guardo conteo/monto agregados por meta para consultas rápidas.
-- =========================================================

CREATE TABLE IF NOT EXISTS cumplimientoMeta (
  id_meta              INT PRIMARY KEY REFERENCES meta(id_meta) ON DELETE CASCADE,
  ventas_cantidad      INT           NOT NULL DEFAULT 0,
  ventas_monto         NUMERIC(12,2) NOT NULL DEFAULT 0,
  updated_at           TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 5) FUNCIÓN: recalcular cumplimiento por meta
--    Nota: la uso desde triggers cuando cambian ventas.
-- =========================================================

CREATE OR REPLACE FUNCTION fn_recalcular_cumplimiento(p_id_meta INT)
RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE
  v_ejecutivo  INT;
  v_categoria  INT;
  v_ini        DATE;
  v_fin        DATE;
  v_cnt        INT;
  v_sum        NUMERIC(12,2);
BEGIN
  SELECT id_ejecutivo, id_categoria, periodo_inicio, periodo_fin
    INTO v_ejecutivo, v_categoria, v_ini, v_fin
  FROM meta WHERE id_meta = p_id_meta;

  IF NOT FOUND THEN
    RETURN; -- Nota: si borraron la meta, no hago nada.
  END IF;

  SELECT COUNT(*)::INT,
         COALESCE(SUM(v.monto), 0)::NUMERIC(12,2)
    INTO v_cnt, v_sum
  FROM venta v
  JOIN producto p ON p.id_producto = v.id_producto
  WHERE v.id_ejecutivo = v_ejecutivo
    AND p.id_categoria = v_categoria
    AND v.fecha BETWEEN v_ini AND v_fin;

  INSERT INTO cumplimientoMeta(id_meta, ventas_cantidad, ventas_monto, updated_at)
  VALUES (p_id_meta, v_cnt, v_sum, CURRENT_TIMESTAMP)
  ON CONFLICT (id_meta) DO UPDATE
  SET ventas_cantidad = EXCLUDED.ventas_cantidad,
      ventas_monto    = EXCLUDED.ventas_monto,
      updated_at      = CURRENT_TIMESTAMP;
END;
$$;

-- =========================================================
-- 6) TRIGGER: recalcular cache cuando cambian ventas
--    Nota: cubro I/U/D y actualizo todas las metas afectadas.
-- =========================================================

CREATE OR REPLACE FUNCTION trg_venta_recalcular_cumplimiento_fn()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
  r RECORD;
BEGIN
  -- metas afectadas por la fila NUEVA (INSERT/UPDATE)
  IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
    FOR r IN
      SELECT m.id_meta
      FROM meta m
      JOIN producto p ON p.id_categoria = m.id_categoria
      WHERE m.id_ejecutivo = NEW.id_ejecutivo
        AND p.id_producto  = NEW.id_producto
        AND NEW.fecha BETWEEN m.periodo_inicio AND m.periodo_fin
    LOOP
      PERFORM fn_recalcular_cumplimiento(r.id_meta);
    END LOOP;
  END IF;

  -- metas afectadas por la fila ANTIGUA (UPDATE/DELETE)
  IF (TG_OP = 'UPDATE' OR TG_OP = 'DELETE') THEN
    FOR r IN
      SELECT m.id_meta
      FROM meta m
      JOIN producto p ON p.id_categoria = m.id_categoria
      WHERE m.id_ejecutivo = OLD.id_ejecutivo
        AND p.id_producto  = OLD.id_producto
        AND OLD.fecha BETWEEN m.periodo_inicio AND m.periodo_fin
    LOOP
      PERFORM fn_recalcular_cumplimiento(r.id_meta);
    END LOOP;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_venta_recalcular_cumplimiento ON venta;
CREATE TRIGGER trg_venta_recalcular_cumplimiento
AFTER INSERT OR UPDATE OR DELETE ON venta
FOR EACH ROW EXECUTE FUNCTION trg_venta_recalcular_cumplimiento_fn();

-- =========================================================
-- 7) SP: upsert de meta + registrar venta
--    Nota: la app llama a estos SP en vez de INSERTs crudos.
-- =========================================================

-- Upsert de meta (si existe mismo período exacto, actualizo)
CREATE OR REPLACE FUNCTION sp_definir_meta(
  p_id_ejecutivo  INT,
  p_id_categoria  INT,
  p_inicio        DATE,
  p_fin           DATE,
  p_cant          INT,
  p_monto         NUMERIC(12,2),
  p_peso          NUMERIC(5,2)
) RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
  v_id_meta INT;
BEGIN
  IF p_fin <= p_inicio THEN
    RAISE EXCEPTION 'El fin de período debe ser mayor al inicio'
      USING ERRCODE='check_violation';
  END IF;

  SELECT id_meta INTO v_id_meta
  FROM meta
  WHERE id_ejecutivo = p_id_ejecutivo
    AND id_categoria = p_id_categoria
    AND periodo_inicio = p_inicio
    AND periodo_fin    = p_fin;

  IF v_id_meta IS NULL THEN
    INSERT INTO meta(periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria)
    VALUES (p_inicio, p_fin, p_cant, p_monto, p_peso, p_id_ejecutivo, p_id_categoria)
    RETURNING id_meta INTO v_id_meta;
  ELSE
    UPDATE meta
       SET cantidad_meta = p_cant,
           monto_meta    = p_monto,
           peso_ponderado= p_peso
     WHERE id_meta = v_id_meta;
  END IF;

  -- recalculo cache por prolijidad (por si ya hay ventas en el período)
  PERFORM fn_recalcular_cumplimiento(v_id_meta);
  RETURN v_id_meta;
END;
$$;

-- Registrar venta (delego validaciones a los triggers)
CREATE OR REPLACE FUNCTION sp_registrar_venta(
  p_fecha        DATE,
  p_monto        NUMERIC(12,2),
  p_id_cliente   INT,
  p_id_producto  INT,
  p_id_ejecutivo INT,
  p_id_canal     INT DEFAULT 1
) RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
  v_id_venta INT;
BEGIN
  INSERT INTO venta(fecha, monto, id_cliente, id_producto, id_ejecutivo, id_canal)
  VALUES (p_fecha, p_monto, p_id_cliente, p_id_producto, p_id_ejecutivo, p_id_canal)
  RETURNING id_venta INTO v_id_venta;

  RETURN v_id_venta;
END;
$$;

-- =========================================================
-- 8) VISTA: metas con avance y cumplimiento ponderado
--    Nota: reporte listo para frontend/analítica.
-- =========================================================

CREATE OR REPLACE VIEW vw_metas_con_avance AS
SELECT
  m.id_meta,
  m.id_ejecutivo,
  m.id_categoria,
  m.periodo_inicio,
  m.periodo_fin,
  m.cantidad_meta,
  m.monto_meta,
  m.peso_ponderado,
  COALESCE(cm.ventas_cantidad, 0)             AS ventas_cantidad,
  COALESCE(cm.ventas_monto, 0)::NUMERIC(12,2) AS ventas_monto,
  CASE WHEN m.cantidad_meta > 0
       THEN LEAST(1.0, COALESCE(cm.ventas_cantidad::DECIMAL / m.cantidad_meta, 0))
       ELSE 0 END                              AS avance_cantidad_pct,
  CASE WHEN m.monto_meta > 0
       THEN LEAST(1.0, COALESCE(cm.ventas_monto / m.monto_meta, 0))
       ELSE 0 END                              AS avance_monto_pct,
  ROUND(
    (
      (CASE WHEN m.cantidad_meta > 0
            THEN LEAST(1.0, COALESCE(cm.ventas_cantidad::DECIMAL / m.cantidad_meta, 0))
            ELSE 0 END)
      +
      (CASE WHEN m.monto_meta > 0
            THEN LEAST(1.0, COALESCE(cm.ventas_monto / m.monto_meta, 0))
            ELSE 0 END)
    )/2 * (m.peso_ponderado/100.0)
  , 4) AS cumplimiento_ponderado
FROM meta m
LEFT JOIN cumplimientoMeta cm ON cm.id_meta = m.id_meta;

COMMIT;
