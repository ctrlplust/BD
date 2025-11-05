const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/canales
router.get('/', async (req, res) => {
  try {
    const result = await db.query('SELECT id_canal, nombre FROM canal ORDER BY nombre LIMIT 100');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener canales' });
  }
});

module.exports = router;
