const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/ventas - devuelve ventas con nombres relacionados y soporta filtros simples (cliente, producto, ejecutivo, fecha range, limit/offset)
router.get('/', async (req, res) => {
  try {
    // filtros opcionales desde query params
    const { id_cliente, id_producto, id_ejecutivo, fecha_inicio, fecha_fin, limit = 200, offset = 0, q } = req.query;

    const clauses = [];
    const params = [];
    let idx = 1;

    if (id_cliente) { clauses.push(`v.id_cliente = $${idx++}`); params.push(Number(id_cliente)); }
    if (id_producto) { clauses.push(`v.id_producto = $${idx++}`); params.push(Number(id_producto)); }
    if (id_ejecutivo) { clauses.push(`v.id_ejecutivo = $${idx++}`); params.push(Number(id_ejecutivo)); }
    if (fecha_inicio) { clauses.push(`v.fecha >= $${idx++}`); params.push(fecha_inicio); }
    if (fecha_fin) { clauses.push(`v.fecha <= $${idx++}`); params.push(fecha_fin); }
    if (q) { clauses.push(`(LOWER(c.nombre) LIKE $${idx} OR LOWER(p.nombre_producto) LIKE $${idx})`); params.push('%' + q.toLowerCase() + '%'); idx++; }

    const where = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';

    const sql = `
      SELECT v.id_venta, v.fecha, v.monto,
             v.id_cliente, c.nombre AS cliente_nombre,
             v.id_producto, p.nombre_producto AS producto_nombre,
             v.id_ejecutivo, e.nombre AS ejecutivo_nombre,
             v.id_canal, ca.nombre AS canal_nombre
      FROM venta v
      LEFT JOIN cliente c ON c.id_cliente = v.id_cliente
      LEFT JOIN producto p ON p.id_producto = v.id_producto
      LEFT JOIN ejecutivo e ON e.id_ejecutivo = v.id_ejecutivo
      LEFT JOIN canal ca ON ca.id_canal = v.id_canal
      ${where}
      ORDER BY v.fecha DESC
      LIMIT $${idx++} OFFSET $${idx++}
    `;

    params.push(Number(limit)); params.push(Number(offset));

    const result = await db.query(sql, params);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener ventas' });
  }
});

// GET /api/ventas/:id
router.get('/:id', async (req, res) => {
  const id = Number(req.params.id);
  try {
    const result = await db.query('SELECT id_venta, fecha, monto, id_cliente, id_producto, id_ejecutivo, id_canal FROM venta WHERE id_venta = $1', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Venta no encontrada' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener venta' });
  }
});

// POST /api/ventas - crear venta simple
router.post('/', async (req, res) => {
  const { fecha, monto, id_cliente, id_producto, id_ejecutivo, id_canal } = req.body;
  console.log('POST /api/ventas body:', req.body);
  // Coerciones y validaciones tolerantes: aceptar strings desde el frontend
  const parsedFecha = fecha ? String(fecha) : null;
  const parsedMonto = monto !== undefined && monto !== null && monto !== '' ? Number(monto) : null;
  const parsedIdCliente = id_cliente !== undefined && id_cliente !== null && id_cliente !== '' ? Number(id_cliente) : null;
  const parsedIdProducto = id_producto !== undefined && id_producto !== null && id_producto !== '' ? Number(id_producto) : null;
  const parsedIdEjecutivo = id_ejecutivo !== undefined && id_ejecutivo !== null && id_ejecutivo !== '' ? Number(id_ejecutivo) : null;
  const parsedIdCanal = id_canal !== undefined && id_canal !== null && id_canal !== '' ? Number(id_canal) : null;

  if (!parsedFecha || !parsedMonto || !parsedIdCliente || !parsedIdProducto) {
    return res.status(400).json({ error: 'fecha, monto, id_cliente y id_producto son requeridos', received: req.body, parsed: { parsedFecha, parsedMonto, parsedIdCliente, parsedIdProducto } });
  }

  try {
    // Postgres will accept ISO date strings for DATE/TIMESTAMP columns; pass parsed values
    const result = await db.query(
      'INSERT INTO venta (fecha, monto, id_cliente, id_producto, id_ejecutivo, id_canal) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id_venta, fecha, monto, id_cliente, id_producto, id_ejecutivo, id_canal',
      [parsedFecha, parsedMonto, parsedIdCliente, parsedIdProducto, parsedIdEjecutivo || null, parsedIdCanal || null]
    );
    console.log('Venta creada:', result.rows[0]);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error al crear venta:', err.message || err, err.stack || '');
    // si hay detalle de constraint, lo devolvemos para depuración
    const detail = err.detail || err.message || 'unknown';
    res.status(500).json({ error: 'Error al crear venta', detail });
  }
});

// DELETE /api/ventas/:id
router.delete('/:id', async (req, res) => {
  const id = Number(req.params.id);
  try {
    const result = await db.query('DELETE FROM venta WHERE id_venta = $1 RETURNING id_venta', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Venta no encontrada' });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al eliminar venta' });
  }
});

module.exports = router;
