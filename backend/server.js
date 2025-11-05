const express = require('express');
const path = require('path');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const app = express();
const PORT = process.env.APP_PORT || 3000;

// Middlewares
app.use(cors());
app.use(express.json());

// API routes
const clientesRouter = require('./routes/clientes');
app.use('/api/clientes', clientesRouter);
const productosRouter = require('./routes/productos');
const ventasRouter = require('./routes/ventas');
const metasRouter = require('./routes/metas');
const ejecutivosRouter = require('./routes/ejecutivos');
const canalesRouter = require('./routes/canales');

app.use('/api/productos', productosRouter);
app.use('/api/ventas', ventasRouter);
app.use('/api/metas', metasRouter);
app.use('/api/ejecutivos', ejecutivosRouter);
app.use('/api/canales', canalesRouter);

// Serve frontend static files
const frontendPath = path.resolve(__dirname, '../frontend');
app.use(express.static(frontendPath));

// Fallback to index.html for SPA
app.get('*', (req, res) => {
  res.sendFile(path.join(frontendPath, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server listening on http://localhost:${PORT}`);
});
