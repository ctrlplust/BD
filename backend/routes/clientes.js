const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/clientes - listar
router.get('/', async (req, res) => {
  try {
    const result = await db.query('SELECT id_cliente, nombre, rut, id_ejecutivo FROM cliente ORDER BY id_cliente LIMIT 100');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener clientes' });
  }
});

// GET /api/clientes/:id - obtener por id
router.get('/:id', async (req, res) => {
  const id = Number(req.params.id);
  try {
    const result = await db.query('SELECT id_cliente, nombre, rut, id_ejecutivo FROM cliente WHERE id_cliente = $1', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Cliente no encontrado' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener cliente' });
  }
});

// POST /api/clientes - crear
router.post('/', async (req, res) => {
  const { nombre, rut, id_ejecutivo } = req.body;
  if (!nombre || !rut) return res.status(400).json({ error: 'Faltan campos: nombre y rut son requeridos' });
  try {
    const result = await db.query(
      'INSERT INTO cliente (nombre, rut, id_ejecutivo) VALUES ($1, $2, $3) RETURNING id_cliente, nombre, rut, id_ejecutivo',
      [nombre, rut, id_ejecutivo || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al crear cliente' });
  }
});

// PUT /api/clientes/:id - actualizar
router.put('/:id', async (req, res) => {
  const id = Number(req.params.id);
  const { nombre, rut, id_ejecutivo } = req.body;
  try {
    const result = await db.query(
      'UPDATE cliente SET nombre = $1, rut = $2, id_ejecutivo = $3 WHERE id_cliente = $4 RETURNING id_cliente, nombre, rut, id_ejecutivo',
      [nombre, rut, id_ejecutivo || null, id]
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'Cliente no encontrado' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al actualizar cliente' });
  }
});

// DELETE /api/clientes/:id - eliminar
router.delete('/:id', async (req, res) => {
  const id = Number(req.params.id);
  try {
    const result = await db.query('DELETE FROM cliente WHERE id_cliente = $1 RETURNING id_cliente', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Cliente no encontrado' });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al eliminar cliente' });
  }
});

module.exports = router;
