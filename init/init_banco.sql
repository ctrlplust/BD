-- =====================================================
--   init_banco.sql
--   Carga de datos de ejemplo / contexto Banco Futura
--   Requiere que init_camiones.sql YA se haya ejecutado
-- =====================================================

BEGIN;

-- Datos base mínimos
INSERT INTO region (nombre, pais)
VALUES ('RM', 'Chile')
ON CONFLICT (nombre, pais) DO NOTHING;

INSERT INTO gerentesucursal (nombre)
VALUES ('Gerente 1')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO tipoejecutivo (nombre_tipo)
VALUES ('Retail'), ('Pyme'), ('VIP')
ON CONFLICT (nombre_tipo) DO NOTHING;

INSERT INTO productocategoria (nombre_categoria)
VALUES ('Tarjetas'), ('Créditos'), ('Cuentas')
ON CONFLICT (nombre_categoria) DO NOTHING;

INSERT INTO canal (nombre)
VALUES ('Mesón'), ('Web'), ('App'), ('Call Center')
ON CONFLICT (nombre) DO NOTHING;

-- Sucursal principal
INSERT INTO sucursal (nombre, direccion, id_region, id_gerente)
VALUES (
  'Sucursal Centro',
  'Av. Principal 123',
  (SELECT id_region FROM region WHERE nombre='RM' AND pais='Chile'),
  (SELECT id_gerente FROM gerentesucursal WHERE nombre='Gerente 1')
)
ON CONFLICT (nombre, id_region) DO NOTHING;

-- Ejecutivo principal
INSERT INTO ejecutivo (nombre, rut, id_tipo, id_sucursal)
VALUES (
  'Ana Pérez', '12.345.678-9',
  (SELECT id_tipo FROM tipoejecutivo WHERE nombre_tipo='Retail'),
  (SELECT id_sucursal FROM sucursal WHERE nombre='Sucursal Centro')
)
ON CONFLICT (rut) DO NOTHING;

-- Cliente demo
INSERT INTO cliente (nombre, rut, id_ejecutivo)
VALUES (
  'Cliente Demo', '9.876.543-2',
  (SELECT id_ejecutivo FROM ejecutivo WHERE rut='12.345.678-9')
)
ON CONFLICT (rut) DO NOTHING;

-- Productos demo
INSERT INTO producto (nombre_producto, id_categoria)
VALUES
  ('Tarjeta Visa', (SELECT id_categoria FROM productocategoria WHERE nombre_categoria='Tarjetas')),
  ('Crédito Consumo', (SELECT id_categoria FROM productocategoria WHERE nombre_categoria='Créditos'))
ON CONFLICT (nombre_producto) DO NOTHING;

-- Venta demo (usa canal "Mesón")
INSERT INTO venta (fecha, monto, id_cliente, id_producto, id_ejecutivo, id_canal)
VALUES (
  CURRENT_DATE,
  150000,
  (SELECT id_cliente FROM cliente WHERE rut='9.876.543-2'),
  (SELECT id_producto FROM producto WHERE nombre_producto='Tarjeta Visa'),
  (SELECT id_ejecutivo FROM ejecutivo WHERE rut='12.345.678-9'),
  (SELECT id_canal FROM canal WHERE nombre='Mesón')
);

-- Metas demo
INSERT INTO meta (periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria)
VALUES
    (
      '2025-10-01', '2025-10-31',
      15, 2000000, 70.00,
      (SELECT id_ejecutivo FROM ejecutivo WHERE rut='12.345.678-9'),
      (SELECT id_categoria FROM productocategoria WHERE nombre_categoria='Tarjetas')
    )
ON CONFLICT DO NOTHING;

COMMIT;
