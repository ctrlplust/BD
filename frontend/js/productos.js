const API_PRODUCTOS = '/api/productos';

async function listarProductos() {
  const res = await fetch(API_PRODUCTOS);
  const data = await res.json();
  const tbody = document.querySelector('#tblProductos tbody');
  tbody.innerHTML = '';
  data.forEach(p => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${p.id_producto}</td>
      <td>${escapeHtml(p.nombre_producto)}</td>
      <td>${p.id_categoria ?? ''}</td>
      <td>
        <button class="btn btn-sm btn-primary me-1" data-id="${p.id_producto}" data-action="edit">Editar</button>
        <button class="btn btn-sm btn-danger" data-id="${p.id_producto}" data-action="delete">Borrar</button>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

document.addEventListener('DOMContentLoaded', () => {
  // productos
  listarProductos();
  const modalP = new bootstrap.Modal(document.getElementById('modalProducto'));
  document.getElementById('btnNuevoProducto').addEventListener('click', () => {
    document.getElementById('productoId').value = '';
    document.getElementById('nombre_producto').value = '';
    document.getElementById('id_categoria_prod').value = '';
    modalP.show();
  });

  document.getElementById('btnGuardarProducto')?.addEventListener('click', async () => {
    const id = document.getElementById('productoId').value;
    const nombre_producto = document.getElementById('nombre_producto').value.trim();
    const id_categoria = document.getElementById('id_categoria_prod').value || null;
    if (!nombre_producto) { alert('Nombre requerido'); return; }
    const payload = { nombre_producto, id_categoria: id_categoria ? Number(id_categoria) : null };
    if (id) await fetch(`${API_PRODUCTOS}/${id}`, { method: 'PUT', headers:{'Content-Type':'application/json'}, body: JSON.stringify(payload) });
    else await fetch(API_PRODUCTOS, { method: 'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(payload) });
    modalP.hide();
    await listarProductos();
  });

  document.querySelector('#tblProductos tbody').addEventListener('click', async (e) => {
    const btn = e.target.closest('button'); if (!btn) return;
    const id = btn.dataset.id; const action = btn.dataset.action;
    if (action === 'edit') {
      const res = await fetch(`${API_PRODUCTOS}/${id}`);
      const p = await res.json();
      document.getElementById('productoId').value = p.id_producto;
      document.getElementById('nombre_producto').value = p.nombre_producto || '';
      document.getElementById('id_categoria_prod').value = p.id_categoria || '';
      modalP.show();
    } else if (action === 'delete') {
      if (!confirm('¿Eliminar producto?')) return;
      await fetch(`${API_PRODUCTOS}/${id}`, { method: 'DELETE' });
      await listarProductos();
    }
  });
});
