const API_METAS = '/api/metas';

async function listarMetas() {
  const res = await fetch(API_METAS);
  const data = await res.json();
  const tbody = document.querySelector('#tblMetas tbody');
  tbody.innerHTML = '';
  data.forEach(m => {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td>${m.id_meta}</td>
      <td>${m.periodo_inicio}</td>
      <td>${m.periodo_fin}</td>
      <td>${m.cantidad_meta ?? ''}</td>
      <td>${m.monto_meta ?? ''}</td>
      <td>${m.id_ejecutivo ?? ''}</td>
      <td>${m.id_categoria ?? ''}</td>
      <td>
        <button class="btn btn-sm btn-primary me-1" data-id="${m.id_meta}" data-action="edit">Editar</button>
        <button class="btn btn-sm btn-danger" data-id="${m.id_meta}" data-action="delete">Borrar</button>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

document.addEventListener('DOMContentLoaded', () => {
  listarMetas();
  const modalM = new bootstrap.Modal(document.getElementById('modalMeta'));
  document.getElementById('btnNuevaMeta')?.addEventListener('click', () => {
    document.getElementById('metaId').value = '';
    document.getElementById('periodo_inicio').value = '';
    document.getElementById('periodo_fin').value = '';
    document.getElementById('cantidad_meta').value = '';
    document.getElementById('monto_meta').value = '';
    document.getElementById('peso_ponderado').value = '';
    document.getElementById('id_ejecutivo_meta').value = '';
    document.getElementById('id_categoria_meta').value = '';
    modalM.show();
  });

  document.getElementById('btnGuardarMeta')?.addEventListener('click', async () => {
    const id = document.getElementById('metaId').value;
    const payload = {
      periodo_inicio: document.getElementById('periodo_inicio').value,
      periodo_fin: document.getElementById('periodo_fin').value,
      cantidad_meta: document.getElementById('cantidad_meta').value || null,
      monto_meta: document.getElementById('monto_meta').value || null,
      peso_ponderado: document.getElementById('peso_ponderado').value || null,
      id_ejecutivo: document.getElementById('id_ejecutivo_meta').value || null,
      id_categoria: document.getElementById('id_categoria_meta').value || null
    };
    if (!payload.periodo_inicio || !payload.periodo_fin) { alert('Periodos requeridos'); return; }
    if (id) await fetch(`${API_METAS}/${id}`, { method: 'PUT', headers:{'Content-Type':'application/json'}, body: JSON.stringify(payload) });
    else await fetch(API_METAS, { method: 'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(payload) });
    modalM.hide();
    await listarMetas();
  });

  document.querySelector('#tblMetas tbody').addEventListener('click', async (e) => {
    const btn = e.target.closest('button'); if (!btn) return;
    const id = btn.dataset.id; const action = btn.dataset.action;
    if (action === 'edit') {
      const res = await fetch(`${API_METAS}/${id}`);
      const m = await res.json();
      document.getElementById('metaId').value = m.id_meta;
      document.getElementById('periodo_inicio').value = m.periodo_inicio || '';
      document.getElementById('periodo_fin').value = m.periodo_fin || '';
      document.getElementById('cantidad_meta').value = m.cantidad_meta || '';
      document.getElementById('monto_meta').value = m.monto_meta || '';
      document.getElementById('peso_ponderado').value = m.peso_ponderado || '';
      document.getElementById('id_ejecutivo_meta').value = m.id_ejecutivo || '';
      document.getElementById('id_categoria_meta').value = m.id_categoria || '';
      modalM.show();
    } else if (action === 'delete') {
      if (!confirm('¿Eliminar meta?')) return;
      await fetch(`${API_METAS}/${id}`, { method: 'DELETE' });
      await listarMetas();
    }
  });
});
