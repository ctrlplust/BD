const API = '/api/clientes';

async function listarClientes() {
  const res = await fetch(API);
  const data = await res.json();
  const tbody = document.querySelector('#tblClientes tbody');
  tbody.innerHTML = '';
  data.forEach(c => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${c.id_cliente}</td>
      <td>${escapeHtml(c.nombre)}</td>
      <td>${escapeHtml(c.rut)}</td>
      <td>${c.id_ejecutivo ?? ''}</td>
      <td>
        <button class="btn btn-sm btn-primary me-1" data-id="${c.id_cliente}" data-action="edit">Editar</button>
        <button class="btn btn-sm btn-danger" data-id="${c.id_cliente}" data-action="delete">Borrar</button>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

function escapeHtml(s) { return (s === null || s === undefined) ? '' : String(s).replace(/[&"'<>]/g, function(m){return {'&':'&amp;','"':'&quot;',"'":"&#39;","<":"&lt;",">":"&gt;"}[m];}); }

document.addEventListener('DOMContentLoaded', () => {
  listarClientes();

  const modalEl = document.getElementById('modalCliente');
  const modal = new bootstrap.Modal(modalEl);

  document.getElementById('btnNuevo').addEventListener('click', () => {
    clearForm();
    modal.show();
  });

  document.getElementById('btnGuardar').addEventListener('click', async () => {
    const id = document.getElementById('clienteId').value;
    const nombre = document.getElementById('nombre').value.trim();
    const rut = document.getElementById('rut').value.trim();
    const id_ejecutivo = document.getElementById('id_ejecutivo').value || null;
    if (!nombre || !rut) {
      document.getElementById('formFeedback').textContent = 'Nombre y RUT son requeridos';
      return;
    }
    const payload = { nombre, rut, id_ejecutivo: id_ejecutivo ? Number(id_ejecutivo) : null };
    try {
      if (id) {
        await fetch(`${API}/${id}`, { method: 'PUT', headers: {'Content-Type':'application/json'}, body: JSON.stringify(payload) });
      } else {
        await fetch(API, { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(payload) });
      }
      modal.hide();
      clearForm();
      await listarClientes();
    } catch (err) {
      console.error(err);
      document.getElementById('formFeedback').textContent = 'Error al guardar cliente';
    }
  });

  document.querySelector('#tblClientes tbody').addEventListener('click', async (e) => {
    const btn = e.target.closest('button');
    if (!btn) return;
    const id = btn.dataset.id;
    const action = btn.dataset.action;
    if (action === 'edit') {
      // fetch data
      const res = await fetch(`${API}/${id}`);
      if (res.ok) {
        const c = await res.json();
        document.getElementById('clienteId').value = c.id_cliente;
        document.getElementById('nombre').value = c.nombre || '';
        document.getElementById('rut').value = c.rut || '';
        document.getElementById('id_ejecutivo').value = c.id_ejecutivo || '';
        document.getElementById('formFeedback').textContent = '';
        modal.show();
      }
    } else if (action === 'delete') {
      if (!confirm('¿Eliminar cliente?')) return;
      await fetch(`${API}/${id}`, { method: 'DELETE' });
      await listarClientes();
    }
  });
});

function clearForm() {
  document.getElementById('clienteId').value = '';
  document.getElementById('nombre').value = '';
  document.getElementById('rut').value = '';
  document.getElementById('id_ejecutivo').value = '';
  document.getElementById('formFeedback').textContent = '';
}
