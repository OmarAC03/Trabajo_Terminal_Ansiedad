// Pruebas de las rutas de especialista.js (Bloque 2) con una base falsa: se
// revisa quién entra, qué SQL corre y que la bitácora vaya en la misma
// transacción. Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { crearEspecialistaRouter } = require('./especialista');

const PACIENTE = 'pac-1';
const ESP = 'esp-1';
const NOTA_ID = '6f1c2b1e-1111-4a2b-9c3d-123456789abc';

// Base falsa: `responder(sql, params)` decide las filas; se anota cada
// consulta (y si fue por el pool o por el cliente de una transacción).
function basesFalsas(responder) {
  const consultas = [];
  const correr = (via) => async (sql, params = []) => {
    consultas.push({ via, sql: sql.trim(), params });
    const filas = (await responder(sql, params)) || [];
    return { rows: filas, rowCount: filas.length };
  };
  const pool = {
    query: correr('pool'),
    connect: async () => ({ query: correr('cliente'), release: () => consultas.push({ via: 'release' }) }),
  };
  return { pool, consultas };
}

// Levanta el router como lo monta server.js, con el uid/rol del encabezado
// (en lugar del token) y el mismo middleware de error.
async function servidor(pool, { vinculado = true } = {}) {
  const accesos = [];
  const app = express();
  app.use(express.json());
  app.use((req, res, next) => {
    req.uid = req.get('x-uid');
    req.rol = req.get('x-rol');
    next();
  });
  app.use('/api/pacientes', crearEspecialistaRouter(pool, {
    esPacienteVinculado: async (pacienteId, especialistaId) => vinculado && pacienteId === PACIENTE && especialistaId === ESP,
    registrarAcceso: async (req, pacienteId, recurso) => accesos.push({ uid: req.uid, pacienteId, recurso }),
  }));
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    const statusCode = err.statusCode || 500;
    res.status(statusCode).json({ error: err.message, ...(err.codigo ? { codigo: err.codigo } : {}) });
  });
  const http = app.listen(0);
  await new Promise((r) => http.once('listening', r));
  const base = `http://127.0.0.1:${http.address().port}/api/pacientes`;
  const pedir = async (metodo, ruta, { uid = ESP, rol = 'especialista', cuerpo } = {}) => {
    const r = await fetch(base + ruta, {
      method: metodo,
      headers: { 'content-type': 'application/json', 'x-uid': uid, 'x-rol': rol },
      body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
    });
    return { status: r.status, cuerpo: await r.json() };
  };
  return { pedir, accesos, cerrar: () => new Promise((r) => http.close(r)) };
}

const hoy = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Mexico_City' }).format(new Date());
const notaFila = (extra = {}) => ({
  id: NOTA_ID, fecha: '2026-11-01', contenido: 'Texto', version: 1, creada_en: '2026-11-01T10:00:00Z', editada_en: null, ...extra,
});
const bitacoraDe = (consultas) => consultas.filter((c) => /INSERT INTO bitacora/.test(c.sql));

test('solo el especialista vinculado: paciente, admin y otro especialista reciben 403', async () => {
  const { pool, consultas } = basesFalsas(() => []);
  const s = await servidor(pool);
  try {
    for (const quien of [
      { uid: PACIENTE, rol: 'paciente' },
      { uid: 'adm-1', rol: 'admin' },
      { uid: 'esp-2', rol: 'especialista' },
    ]) {
      assert.equal((await s.pedir('GET', `/${PACIENTE}/notas`, quien)).status, 403, quien.rol);
      assert.equal((await s.pedir('POST', `/${PACIENTE}/notas`, { ...quien, cuerpo: { fecha: hoy(), contenido: 'x' } })).status, 403);
    }
    assert.equal(consultas.length, 0);
    assert.equal(s.accesos.length, 0);
  } finally {
    await s.cerrar();
  }
});

test('listar: filtra por el par y registra el acceso como recurso "notas"', async () => {
  const { pool, consultas } = basesFalsas(() => [notaFila()]);
  const s = await servidor(pool);
  try {
    const r = await s.pedir('GET', `/${PACIENTE}/notas`);
    assert.equal(r.status, 200);
    assert.equal(r.cuerpo[0].id, NOTA_ID);
    assert.deepEqual(consultas[0].params, [PACIENTE, ESP]);
    assert.deepEqual(s.accesos, [{ uid: ESP, pacienteId: PACIENTE, recurso: 'notas' }]);
  } finally {
    await s.cerrar();
  }
});

test('crear: INSERT y bitácora en la misma transacción, sin el contenido', async () => {
  const { pool, consultas } = basesFalsas((sql) => (/INSERT INTO notas_clinicas/.test(sql) ? [notaFila()] : []));
  const s = await servidor(pool);
  try {
    const r = await s.pedir('POST', `/${PACIENTE}/notas`, { cuerpo: { fecha: hoy(), contenido: 'Contenido clínico' } });
    assert.equal(r.status, 201);
    assert.deepEqual(consultas.map((c) => c.via), ['cliente', 'cliente', 'cliente', 'cliente', 'release']);
    assert.equal(consultas[0].sql, 'BEGIN');
    assert.deepEqual(consultas[1].params, [PACIENTE, ESP, hoy(), 'Contenido clínico']);
    const [registro] = bitacoraDe(consultas);
    assert.equal(registro.via, 'cliente');
    assert.deepEqual(registro.params.slice(0, 4), [ESP, 'especialista', 'nota_creada', PACIENTE]);
    assert.deepEqual(JSON.parse(registro.params[4]), { nota_id: NOTA_ID });
    assert.equal(consultas[3].sql, 'COMMIT');
  } finally {
    await s.cerrar();
  }
});

test('crear: si la bitácora falla, se revierte la nota (500)', async () => {
  const { pool, consultas } = basesFalsas((sql) => {
    if (/INSERT INTO bitacora/.test(sql)) throw new Error('sin tabla');
    return /INSERT INTO notas_clinicas/.test(sql) ? [notaFila()] : [];
  });
  const s = await servidor(pool);
  try {
    const r = await s.pedir('POST', `/${PACIENTE}/notas`, { cuerpo: { fecha: hoy(), contenido: 'x' } });
    assert.equal(r.status, 500);
    assert.ok(consultas.some((c) => c.sql === 'ROLLBACK'));
    assert.ok(!consultas.some((c) => c.sql === 'COMMIT'));
  } finally {
    await s.cerrar();
  }
});

test('editar: guarda la versión anterior, sube la versión y la registra', async () => {
  const { pool, consultas } = basesFalsas((sql) => {
    if (/FOR UPDATE/.test(sql)) return [notaFila()];
    if (/UPDATE notas_clinicas/.test(sql)) return [notaFila({ contenido: 'Nuevo', version: 2 })];
    return [];
  });
  const s = await servidor(pool);
  try {
    const r = await s.pedir('PUT', `/${PACIENTE}/notas/${NOTA_ID}`, { cuerpo: { fecha: '2026-11-01', contenido: 'Nuevo', version: 1 } });
    assert.equal(r.status, 200);
    assert.equal(r.cuerpo.version, 2);
    const orden = consultas.filter((c) => c.via === 'cliente').map((c) => c.sql.split(/\s+/).slice(0, 3).join(' '));
    assert.deepEqual(orden, [
      'BEGIN', 'SELECT id, to_char(fecha,', 'INSERT INTO notas_clinicas_versiones', 'UPDATE notas_clinicas SET',
      'INSERT INTO bitacora', 'COMMIT',
    ]);
    assert.deepEqual(consultas[1].params, [NOTA_ID, PACIENTE, ESP]);
    assert.deepEqual(JSON.parse(bitacoraDe(consultas)[0].params[4]), { nota_id: NOTA_ID, version: 2 });
  } finally {
    await s.cerrar();
  }
});

test('editar: versión vieja → 409, sin cambios → 200 sin versión nueva, de otro → 404', async () => {
  let fila = notaFila({ version: 3 });
  const { pool, consultas } = basesFalsas((sql) => (/FOR UPDATE/.test(sql) ? (fila ? [fila] : []) : []));
  const s = await servidor(pool);
  try {
    const vieja = await s.pedir('PUT', `/${PACIENTE}/notas/${NOTA_ID}`, { cuerpo: { fecha: '2026-11-01', contenido: 'B', version: 2 } });
    assert.equal(vieja.status, 409);
    assert.equal(vieja.cuerpo.codigo, 'nota_desactualizada');

    const igual = await s.pedir('PUT', `/${PACIENTE}/notas/${NOTA_ID}`, { cuerpo: { fecha: '2026-11-01', contenido: 'Texto', version: 3 } });
    assert.equal(igual.status, 200);
    assert.equal(igual.cuerpo.version, 3);

    fila = null;
    assert.equal((await s.pedir('PUT', `/${PACIENTE}/notas/${NOTA_ID}`, { cuerpo: { fecha: '2026-11-01', contenido: 'B', version: 3 } })).status, 404);
    assert.equal((await s.pedir('PUT', `/${PACIENTE}/notas/no-es-uuid`, { cuerpo: { fecha: '2026-11-01', contenido: 'B', version: 3 } })).status, 400);

    assert.ok(!consultas.some((c) => /notas_clinicas_versiones|INSERT INTO bitacora/.test(c.sql)));
  } finally {
    await s.cerrar();
  }
});

test('versiones: 404 si la nota no es del par; si lo es, las lista y registra el acceso', async () => {
  let existe = false;
  const { pool } = basesFalsas((sql) => {
    if (/SELECT 1 FROM notas_clinicas/.test(sql)) return existe ? [{ '?column?': 1 }] : [];
    return [{ version: 1, fecha: '2026-11-01', contenido: 'Texto', escrita_en: 'x', reemplazada_en: 'y' }];
  });
  const s = await servidor(pool);
  try {
    assert.equal((await s.pedir('GET', `/${PACIENTE}/notas/${NOTA_ID}/versiones`)).status, 404);
    assert.equal(s.accesos.length, 0);
    existe = true;
    const r = await s.pedir('GET', `/${PACIENTE}/notas/${NOTA_ID}/versiones`);
    assert.equal(r.status, 200);
    assert.equal(r.cuerpo[0].version, 1);
    assert.deepEqual(s.accesos.map((a) => a.recurso), ['notas']);
  } finally {
    await s.cerrar();
  }
});
