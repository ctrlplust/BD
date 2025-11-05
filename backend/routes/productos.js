const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/productos
router.get('/', async (req, res) => {
  try {
    const result = await db.query('SELECT id_producto, nombre_producto, id_categoria FROM producto ORDER BY id_producto LIMIT 200');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener productos' });
  }
});

// GET /api/productos/:id
router.get('/:id', async (req, res) => {
  const id = Number(req.params.id);
  try {
    const result = await db.query('SELECT id_producto, nombre_producto, id_categoria FROM producto WHERE id_producto = $1', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Producto no encontrado' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener producto' });
  }
});

// POST /api/productos
router.post('/', async (req, res) => {
  const { nombre_producto, id_categoria } = req.body;
  if (!nombre_producto) return res.status(400).json({ error: 'nombre_producto es requerido' });
  try {
    const result = await db.query(
      'INSERT INTO producto (nombre_producto, id_categoria) VALUES ($1, $2) RETURNING id_producto, nombre_producto, id_categoria',
      [nombre_producto, id_categoria || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al crear producto' });
  }
});

// PUT /api/productos/:id
router.put('/:id', async (req, res) => {
  const id = Number(req.params.id);
  const { nombre_producto, id_categoria } = req.body;
  try {
    const result = await db.query(
      'UPDATE producto SET nombre_producto = $1, id_categoria = $2 WHERE id_producto = $3 RETURNING id_producto, nombre_producto, id_categoria',
      [nombre_producto, id_categoria || null, id]
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'Producto no encontrado' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al actualizar producto' });
  }
});

// DELETE /api/productos/:id
router.delete('/:id', async (req, res) => {
  const id = Number(req.params.id);
  try {
    const result = await db.query('DELETE FROM producto WHERE id_producto = $1 RETURNING id_producto', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Producto no encontrado' });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al eliminar producto' });
  }
});

module.exports = router;
