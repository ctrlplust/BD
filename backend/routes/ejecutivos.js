const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/ejecutivos - listar básicos
router.get('/', async (req, res) => {
  try {
    const result = await db.query('SELECT id_ejecutivo, nombre FROM ejecutivo ORDER BY nombre LIMIT 1000');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener ejecutivos' });
  }
});

module.exports = router;
