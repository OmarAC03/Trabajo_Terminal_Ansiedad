// Pruebas de cuenta_especialista.js (versión final, Fase 2 del portal).
const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const {
  crearCuentaEspecialistaRouter, vistaConversaciones, vistaExportaciones, vistaResumenPerfil,
  CONVERSACIONES, EXPORTACIONES, RESUMEN_PERFIL, LIMITE_EXPORTACIONES, ZONA_HORARIA,
} = require('./cuenta_especialista');

// --- Bandeja ---

const fila = (extra) => ({ paciente_id: 'p', nombre: 'X', ultima_fecha: null, ultimo_de: null, sin_responder: 0, ...extra });

test('pendiente de responder = el último mensaje es del paciente', () => {
  const [a, b, c] = vistaConversaciones([
    fila({ paciente_id: 'a', ultima_fecha: '2026-11-10T10:00:00Z', ultimo_de: 'paciente', sin_responder: 3 }),
    fila({ paciente_id: 'b', ultima_fecha: '2026-11-10T11:00:00Z', ultimo_de: 'especialista', sin_responder: 0 }),
    fila({ paciente_id: 'c' }),
  ]);
  assert.deepEqual([a.paciente_id, a.pendiente, a.sin_responder], ['a', true, 3]);
  assert.deepEqual([b.paciente_id, b.pendiente, b.sin_responder], ['b', false, 0]);
  assert.deepEqual([c.paciente_id, c.pendiente, c.ultimo_de, c.ultima_fecha], ['c', false, null, null]);
});

test('una pendiente cuenta al menos 1 aunque el conteo llegue en 0', () => {
  const [a] = vistaConversaciones([fila({ ultima_fecha: '2026-11-10T10:00:00Z', ultimo_de: 'paciente', sin_responder: 0 })]);
  assert.equal(a.sin_responder, 1);
});

test('orden: pendientes, luego con mensajes, luego sin mensajes por nombre', () => {
  const orden = vistaConversaciones([
    fila({ paciente_id: 'sin-b', nombre: 'Beto' }),
    fila({ paciente_id: 'resp-vieja', ultima_fecha: '2026-11-01T10:00:00Z', ultimo_de: 'especialista' }),
    fila({ paciente_id: 'pend-vieja', ultima_fecha: '2026-11-02T10:00:00Z', ultimo_de: 'paciente', sin_responder: 1 }),
    fila({ paciente_id: 'sin-a', nombre: 'Ana' }),
    fila({ paciente_id: 'resp-nueva', ultima_fecha: '2026-11-09T10:00:00Z', ultimo_de: 'especialista' }),
    fila({ paciente_id: 'pend-nueva', ultima_fecha: '2026-11-08T10:00:00Z', ultimo_de: 'paciente', sin_responder: 2 }),
  ]).map((c) => c.paciente_id);
  assert.deepEqual(orden, ['pend-nueva', 'pend-vieja', 'resp-nueva', 'resp-vieja', 'sin-a', 'sin-b']);
});

test('la bandeja no trae el texto de ningún mensaje', () => {
  const [c] = vistaConversaciones([fila({ ultima_fecha: '2026-11-10T10:00:00Z', ultimo_de: 'paciente', texto: 'secreto' })]);
  assert.deepEqual(Object.keys(c).sort(), ['nombre', 'paciente_id', 'pendiente', 'sin_responder', 'ultima_fecha', 'ultimo_de']);
  assert.doesNotMatch(CONVERSACIONES, /m\.texto|\btexto\b/);
});

test('la consulta de la bandeja se limita a los vinculados del especialista y a su conversación', () => {
  assert.match(CONVERSACIONES, /u\.rol = 'paciente' AND u\.especialista_id = \$1/);
  assert.match(CONVERSACIONES, /m\.especialista_id = \$1/);
  assert.match(CONVERSACIONES, /COALESCE\(um\.remitente_id, um\.paciente_id\)/);
});

// --- Exportaciones ---

test('exportaciones: con nombre solo si el paciente sigue vinculado', () => {
  const [vinc, ya] = vistaExportaciones([
    { id: '12', fecha: '2026-11-10T15:00:00Z', objetivo_id: 'p1', nombre: 'Ana', vinculado: true,
      detalle: { formato: 'csv', seudonimizado: true, desde: '2026-10-12', hasta: '2026-11-10' } },
    { id: '11', fecha: '2026-11-09T15:00:00Z', objetivo_id: 'p2', nombre: 'Beto', vinculado: false,
      detalle: { formato: 'pdf', seudonimizado: false, desde: '2026-10-11', hasta: '2026-11-09' } },
  ]);
  assert.deepEqual(vinc, {
    id: '12', fecha: '2026-11-10T15:00:00.000Z', paciente_id: 'p1', paciente_nombre: 'Ana', vinculado: true,
    formato: 'csv', seudonimizado: true, desde: '2026-10-12', hasta: '2026-11-10',
  });
  assert.equal(ya.vinculado, false);
  assert.equal(ya.paciente_id, null);
  assert.equal(ya.paciente_nombre, null);
  assert.equal(ya.formato, 'pdf');
});

test('exportaciones: un detalle raro no rompe la vista', () => {
  const [f] = vistaExportaciones([{ id: 5, fecha: '2026-11-10T15:00:00Z', objetivo_id: 'p', vinculado: null, detalle: null }]);
  assert.deepEqual([f.id, f.vinculado, f.formato, f.seudonimizado, f.desde], ['5', false, null, false, null]);
});

test('exportaciones: solo las del propio especialista, en orden, con límite', () => {
  assert.match(EXPORTACIONES, /b\.actor_id = \$1 AND b\.accion = 'exportacion'/);
  assert.match(EXPORTACIONES, /ORDER BY b\.fecha DESC/);
  assert.match(EXPORTACIONES, /LIMIT \$2/);
  assert.equal(LIMITE_EXPORTACIONES, 100);
});

// --- Resumen ---

test('resumen del perfil: enteros y fecha ISO; sin fila, ceros', () => {
  assert.deepEqual(vistaResumenPerfil({
    fecha_registro: '2026-09-01T18:00:00Z', pacientes_vinculados: 4, mensajes_enviados: '17',
    notas_registradas: 2, exportaciones_mes: 1,
  }), {
    fecha_registro: '2026-09-01T18:00:00.000Z', pacientes_vinculados: 4, mensajes_enviados: 17,
    notas_registradas: 2, exportaciones_mes: 1,
  });
  assert.deepEqual(vistaResumenPerfil(undefined), {
    fecha_registro: null, pacientes_vinculados: 0, mensajes_enviados: 0, notas_registradas: 0, exportaciones_mes: 0,
  });
  assert.match(RESUMEN_PERFIL, /date_trunc\('month', now\(\) AT TIME ZONE \$2\) AT TIME ZONE \$2/);
  assert.equal(ZONA_HORARIA, 'America/Mexico_City');
});

// --- Rutas (Express en memoria con una base falsa) ---

function servidor(rol, respuestas) {
  const consultas = [];
  const pool = {
    query: async (sql, params) => {
      consultas.push({ sql, params });
      if (sql === CONVERSACIONES) return { rows: respuestas.conversaciones || [] };
      if (sql === EXPORTACIONES) return { rows: respuestas.exportaciones || [] };
      if (sql === RESUMEN_PERFIL) return { rows: [respuestas.resumen || {}] };
      throw new Error('consulta inesperada');
    },
  };
  const app = express();
  app.use((req, res, next) => { req.uid = 'esp-1'; req.rol = rol; next(); });
  app.use('/api/especialista', crearCuentaEspecialistaRouter(pool));
  app.use((err, req, res, next) => res.status(err.statusCode || 500).json({ error: err.message }));
  return new Promise((resolve) => {
    const s = app.listen(0, () => resolve({ s, consultas, url: `http://127.0.0.1:${s.address().port}/api/especialista` }));
  });
}

for (const rol of ['paciente', 'admin', null]) {
  test(`rol ${rol}: 403 en las tres rutas y no consulta la base`, async () => {
    const { s, consultas, url } = await servidor(rol, {});
    try {
      for (const ruta of ['conversaciones', 'exportaciones', 'resumen']) {
        const r = await fetch(`${url}/${ruta}`);
        assert.equal(r.status, 403, ruta);
      }
      assert.equal(consultas.length, 0);
    } finally { s.close(); }
  });
}

test('especialista: cada ruta consulta con su propio uid', async () => {
  const { s, consultas, url } = await servidor('especialista', {
    conversaciones: [fila({ paciente_id: 'a', ultima_fecha: '2026-11-10T10:00:00Z', ultimo_de: 'paciente', sin_responder: 2 })],
    exportaciones: [{ id: '1', fecha: '2026-11-10T10:00:00Z', objetivo_id: 'a', nombre: 'Ana', vinculado: true, detalle: { formato: 'csv' } }],
    resumen: { pacientes_vinculados: 3 },
  });
  try {
    const conv = await (await fetch(`${url}/conversaciones`)).json();
    assert.equal(conv[0].sin_responder, 2);
    const exp = await fetch(`${url}/exportaciones`);
    assert.equal(exp.headers.get('cache-control'), 'no-store');
    assert.equal((await exp.json()).filas[0].paciente_nombre, 'Ana');
    const res = await (await fetch(`${url}/resumen`)).json();
    assert.equal(res.pacientes_vinculados, 3);
    assert.deepEqual(consultas.map((c) => c.params), [['esp-1'], ['esp-1', 100], ['esp-1', 'America/Mexico_City']]);
  } finally { s.close(); }
});
