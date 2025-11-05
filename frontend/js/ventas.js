const API_VENTAS = '/api/ventas';
const API_CLIENTES = '/api/clientes';
const API_EJECUTIVOS = '/api/ejecutivos';
const API_CANALES = '/api/canales';

let ventasCache = [];
let pageSize = 10;
let currentPage = 1;
let catalogsCache = null; // will hold clientes, productos, ejecutivos, canales

async function fetchCatalogs() {
  const [clientes, productos, ejecutivos, canales] = await Promise.all([
    fetch(API_CLIENTES).then(r => r.json()),
    fetch(API_PRODUCTOS).then(r => r.json()),
    fetch(API_EJECUTIVOS).then(r => r.json()),
    fetch(API_CANALES).then(r => r.json())
  ]);
  return { clientes, productos, ejecutivos, canales };
}

// Comprueba si existe una meta vigente para (id_ejecutivo, id_categoria) en la fecha dada
async function checkMetaExists(id_ejecutivo, id_categoria, fecha) {
  if (!id_ejecutivo || !id_categoria || !fecha) return { exists: false };
  const params = new URLSearchParams({ id_ejecutivo: String(id_ejecutivo), id_categoria: String(id_categoria), fecha });
  const res = await fetch('/api/metas/exists?' + params.toString());
  if (!res.ok) return { exists: false };
  return await res.json();
}

// Crear una meta corta que cubra la fecha dada. Devuelve la meta creada o lanza error.
async function createQuickMeta({ id_ejecutivo, id_categoria, fecha, monto_meta }) {
  // Calcular fecha fin como el día siguiente
  const fechaInicio = new Date(fecha);
  const fechaFin = new Date(fechaInicio);
  fechaFin.setDate(fechaFin.getDate() + 1);
  
  const body = {
    periodo_inicio: fecha,
    periodo_fin: fechaFin.toISOString().split('T')[0],
    cantidad_meta: 1,
    monto_meta: monto_meta || null,
    peso_ponderado: 100,
    id_ejecutivo: id_ejecutivo,
    id_categoria: id_categoria
  };
  const res = await fetch('/api/metas', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(body) });
  if (!res.ok) {
    const txt = await res.text();
    console.error('Response:', txt);
    console.error('Request body:', JSON.stringify(body, null, 2));
    throw new Error('Error creando meta: ' + txt);
  }
  return await res.json();
}

function fillSelect(selectEl, items, valueKey, labelKey, includeEmpty=true) {
  selectEl.innerHTML = '';
  if (includeEmpty) selectEl.insertAdjacentHTML('beforeend', `<option value="">--</option>`);
  items.forEach(it => selectEl.insertAdjacentHTML('beforeend', `<option value="${it[valueKey]}">${escapeHtml(it[labelKey] || it[valueKey])}</option>`));
}

async function listarVentas(filters = {}) {
  // fetch vendas con filtros y paginación server-side
  const params = new URLSearchParams();
  if (filters.id_cliente) params.set('id_cliente', filters.id_cliente);
  if (filters.id_producto) params.set('id_producto', filters.id_producto);
  if (filters.id_ejecutivo) params.set('id_ejecutivo', filters.id_ejecutivo);
  if (filters.fecha_inicio) params.set('fecha_inicio', filters.fecha_inicio);
  if (filters.fecha_fin) params.set('fecha_fin', filters.fecha_fin);
  if (filters.q) params.set('q', filters.q);
  // request more rows than pageSize and handle offset
  const offset = (currentPage - 1) * pageSize;
  params.set('limit', pageSize);
  params.set('offset', offset);

  const res = await fetch(API_VENTAS + '?' + params.toString());
  const data = await res.json();
  ventasCache = data; // current page
  renderVentas(data);
}

function renderVentas(list) {
  const tbody = document.querySelector('#tblVentas tbody');
  tbody.innerHTML = '';
  list.forEach(v => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${v.id_venta}</td>
      <td>${(v.fecha||'').substring(0,10)}</td>
      <td>${v.monto}</td>
      <td>${escapeHtml(v.cliente_nombre || v.id_cliente)}</td>
      <td>${escapeHtml(v.producto_nombre || v.id_producto)}</td>
      <td>
        <button class="btn btn-sm btn-primary me-1" data-id="${v.id_venta}" data-action="edit">Editar</button>
        <button class="btn btn-sm btn-danger" data-id="${v.id_venta}" data-action="delete">Borrar</button>
      </td>
    `;
    tbody.appendChild(tr);
  });
  renderPagination();
}

function renderPagination() {
  const pagerId = 'ventasPager';
  let pager = document.getElementById(pagerId);
  if (!pager) {
    pager = document.createElement('div'); pager.id = pagerId; pager.className = 'mt-2';
    document.querySelector('#ventas').appendChild(pager);
  }
  pager.innerHTML = `
    <div class="d-flex align-items-center gap-2">
      <button id="prevPage" class="btn btn-sm btn-outline-secondary">Anterior</button>
      <span> Página ${currentPage} </span>
      <button id="nextPage" class="btn btn-sm btn-outline-secondary">Siguiente</button>
    </div>
  `;
  pager.querySelector('#prevPage').disabled = currentPage <= 1;
  pager.querySelector('#nextPage').disabled = ventasCache.length < pageSize;
  pager.querySelector('#prevPage').onclick = async () => { if (currentPage>1) { currentPage--; await applyFiltersAndReload(); } };
  pager.querySelector('#nextPage').onclick = async () => { if (ventasCache.length===pageSize) { currentPage++; await applyFiltersAndReload(); } };
}

document.addEventListener('DOMContentLoaded', async () => {
  const catalogs = await fetchCatalogs();
  catalogsCache = catalogs;
  // fill selects used in modal and filters
  fillSelect(document.getElementById('venta_cliente'), catalogs.clientes, 'id_cliente', 'nombre', false);
  fillSelect(document.getElementById('venta_producto'), catalogs.productos, 'id_producto', 'nombre_producto', false);
  fillSelect(document.getElementById('venta_ejecutivo'), catalogs.ejecutivos, 'id_ejecutivo', 'nombre', true);
  fillSelect(document.getElementById('venta_canal'), catalogs.canales, 'id_canal', 'nombre', true);

  fillSelect(document.getElementById('filter_ejecutivo'), catalogs.ejecutivos, 'id_ejecutivo', 'nombre', true);
  fillSelect(document.getElementById('filter_cliente'), catalogs.clientes, 'id_cliente', 'nombre', true);

  // initial load
  await listarVentas();

  const modalEl = document.getElementById('modalVenta');
  const modal = new bootstrap.Modal(modalEl);

  document.getElementById('btnNuevaVenta').addEventListener('click', () => {
    clearVentaForm();
    modal.show();
  });
  document.getElementById('btnGuardarVenta').addEventListener('click', async () => {
    const id = document.getElementById('ventaId').value;
    const fecha = document.getElementById('venta_fecha').value;
    const monto = document.getElementById('venta_monto').value;
    const id_cliente = document.getElementById('venta_cliente').value;
    const id_producto = document.getElementById('venta_producto').value;
    const id_ejecutivo = document.getElementById('venta_ejecutivo').value || null;
    const id_canal = document.getElementById('venta_canal').value || null;
    if (!fecha || !monto || !id_cliente || !id_producto) { document.getElementById('formVentaFeedback').textContent = 'Fecha, monto, cliente y producto son requeridos'; return; }
    const payload = { fecha, monto, id_cliente: Number(id_cliente), id_producto: Number(id_producto), id_ejecutivo: id_ejecutivo ? Number(id_ejecutivo): null, id_canal: id_canal? Number(id_canal): null };
    try {
      // Antes de intentar crear la venta, comprobamos si hay meta vigente para (ejecutivo, categoria)
      // obtener id_categoria desde el producto
      const prod = (catalogsCache && catalogsCache.productos) ? catalogsCache.productos.find(p => String(p.id_producto) === String(id_producto)) : null;
      const id_categoria = prod ? prod.id_categoria : null;

      if (id_ejecutivo && id_categoria) {
        const existsRes = await checkMetaExists(id_ejecutivo, id_categoria, fecha);
        if (!existsRes.exists) {
          // preguntar al usuario si quiere crear una meta rápida
          const ok = confirm('No hay meta vigente para este ejecutivo y categoría en la fecha seleccionada. ¿Crear una meta rápida (período único en esa fecha) automáticamente y luego guardar la venta?');
          if (ok) {
            try {
              await createQuickMeta({ id_ejecutivo: Number(id_ejecutivo), id_categoria: Number(id_categoria), fecha, monto_meta: Number(monto) });
              // recargar metas cache (optional) - we rely on subsequent check to succeed
            } catch (e) {
              console.error(e);
              document.getElementById('formVentaFeedback').textContent = 'Error al crear meta automática: ' + (e.message || e);
              return;
            }
          } else {
            document.getElementById('formVentaFeedback').textContent = 'Necesita una meta vigente para crear la venta. Cree una meta o cambie ejecutivo/producto.';
            return;
          }
        }
      }

      if (id) {
        // API lacks PUT for ventas; delete+post to approximate edit
        await fetch(`${API_VENTAS}/${id}`, { method: 'DELETE' });
        const res = await fetch(API_VENTAS, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(payload) });
        if (!res.ok) {
          const txt = await res.text(); console.error('Error updating sale', txt); throw new Error('Error al actualizar venta');
        }
      } else {
        const res = await fetch(API_VENTAS, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(payload) });
        if (!res.ok) {
          const txt = await res.text(); console.error('Error creating sale', txt); throw new Error('Error al crear venta: ' + txt);
        }
      }
      modal.hide();
      await applyFiltersAndReload();
    } catch (err) {
      console.error(err);
      document.getElementById('formVentaFeedback').textContent = 'Error al guardar venta';
    }
  });

  document.querySelector('#tblVentas tbody').addEventListener('click', async (e) => {
    const btn = e.target.closest('button'); if (!btn) return;
    const id = btn.dataset.id; const action = btn.dataset.action;
    if (action === 'edit') {
      const res = await fetch(`${API_VENTAS}?limit=1&offset=0&q=&`);
      // fetch the single sale by calling GET /api/ventas and filter; simpler: call GET /api/ventas and find the id
      const all = await fetch(API_VENTAS + `?limit=200&offset=0`).then(r => r.json());
      const v = all.find(x => String(x.id_venta) === String(id));
      if (v) {
        document.getElementById('ventaId').value = v.id_venta;
        document.getElementById('venta_fecha').value = (v.fecha||'').substring(0,10);
        document.getElementById('venta_monto').value = v.monto;
        document.getElementById('venta_cliente').value = v.id_cliente || '';
        document.getElementById('venta_producto').value = v.id_producto || '';
        document.getElementById('venta_ejecutivo').value = v.id_ejecutivo || '';
        document.getElementById('venta_canal').value = v.id_canal || '';
        document.getElementById('formVentaFeedback').textContent = '';
        modal.show();
      }
    } else if (action === 'delete') {
      if (!confirm('¿Eliminar venta?')) return;
      await fetch(`${API_VENTAS}/${id}`, { method: 'DELETE' });
      await applyFiltersAndReload();
    }
  });

  document.getElementById('btnAplicarFiltros').addEventListener('click', async () => { currentPage = 1; await applyFiltersAndReload(); });
  document.getElementById('btnLimpiarFiltros').addEventListener('click', async () => { document.getElementById('filter_search').value=''; document.getElementById('filter_fecha_inicio').value=''; document.getElementById('filter_fecha_fin').value=''; document.getElementById('filter_ejecutivo').value=''; document.getElementById('filter_cliente').value=''; currentPage=1; await applyFiltersAndReload(); });
});

async function applyFiltersAndReload() {
  const filters = {
    fecha_inicio: document.getElementById('filter_fecha_inicio').value || undefined,
    fecha_fin: document.getElementById('filter_fecha_fin').value || undefined,
    id_ejecutivo: document.getElementById('filter_ejecutivo').value || undefined,
    id_cliente: document.getElementById('filter_cliente').value || undefined,
    q: document.getElementById('filter_search').value || undefined
  };
  await listarVentas(filters);
}

function clearVentaForm() {
  document.getElementById('ventaId').value = '';
  document.getElementById('venta_fecha').value = '';
  document.getElementById('venta_monto').value = '';
  document.getElementById('venta_cliente').value = '';
  document.getElementById('venta_producto').value = '';
  document.getElementById('venta_ejecutivo').value = '';
  document.getElementById('venta_canal').value = '';
  document.getElementById('formVentaFeedback').textContent = '';
}

