const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/metas
router.get('/', async (req, res) => {
  try {
    const result = await db.query('SELECT id_meta, periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria FROM meta ORDER BY periodo_inicio DESC LIMIT 200');
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener metas' });
  }
});

// GET /api/metas/exists?id_ejecutivo=...&id_categoria=...&fecha=YYYY-MM-DD
router.get('/exists', async (req, res) => {
  try {
    const { id_ejecutivo, id_categoria, fecha } = req.query;
    if (!id_ejecutivo || !id_categoria || !fecha) return res.status(400).json({ error: 'id_ejecutivo, id_categoria y fecha son requeridos' });
    const sql = `SELECT id_meta, periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria
                 FROM meta WHERE id_ejecutivo = $1 AND id_categoria = $2 AND periodo_inicio <= $3 AND periodo_fin >= $3 LIMIT 1`;
    const result = await db.query(sql, [Number(id_ejecutivo), Number(id_categoria), fecha]);
    if (result.rowCount === 0) return res.json({ exists: false, meta: null });
    return res.json({ exists: true, meta: result.rows[0] });
  } catch (err) {
    console.error('Error checking meta exists', err);
    res.status(500).json({ error: 'Error al comprobar existencia de meta' });
  }
});

// GET /api/metas/:id
router.get('/:id', async (req, res) => {
  const id = Number(req.params.id);
  try {
    const result = await db.query('SELECT id_meta, periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria FROM meta WHERE id_meta = $1', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Meta no encontrada' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener meta' });
  }
});

// POST /api/metas
router.post('/', async (req, res) => {
  const { periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria } = req.body;
  if (!periodo_inicio || !periodo_fin) return res.status(400).json({ error: 'periodo_inicio y periodo_fin son requeridos' });
  try {
    const result = await db.query(
      `INSERT INTO meta (periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id_meta, periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria`,
      [periodo_inicio, periodo_fin, cantidad_meta || null, monto_meta || null, peso_ponderado || null, id_ejecutivo || null, id_categoria || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Error detallado:', err);
    res.status(500).json({ error: 'Error al crear meta', details: err.message });
  }
});

// PUT /api/metas/:id
router.put('/:id', async (req, res) => {
  const id = Number(req.params.id);
  const { periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria } = req.body;
  try {
    const result = await db.query(
      `UPDATE meta SET periodo_inicio=$1, periodo_fin=$2, cantidad_meta=$3, monto_meta=$4, peso_ponderado=$5, id_ejecutivo=$6, id_categoria=$7
       WHERE id_meta=$8 RETURNING id_meta, periodo_inicio, periodo_fin, cantidad_meta, monto_meta, peso_ponderado, id_ejecutivo, id_categoria`,
      [periodo_inicio, periodo_fin, cantidad_meta || null, monto_meta || null, peso_ponderado || null, id_ejecutivo || null, id_categoria || null, id]
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'Meta no encontrada' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al actualizar meta' });
  }
});

// DELETE /api/metas/:id
router.delete('/:id', async (req, res) => {
  const id = Number(req.params.id);
  try {
    const result = await db.query('DELETE FROM meta WHERE id_meta = $1 RETURNING id_meta', [id]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Meta no encontrada' });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al eliminar meta' });
  }
});

module.exports = router;
