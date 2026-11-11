'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const cors = require('cors');
const {
  ORIGEN_PORTAL, origenesPermitidos, origenPermitido, opcionesCors, opcionesSocket,
  crearLimites, RUTAS_ESTRICTAS, MENSAJE_429, CODIGO_429, LIMITES,
} = require('./seguridad');

test('orígenes: en producción solo el portal; fuera, también localhost:3000', () => {
  assert.equal(ORIGEN_PORTAL, 'https://monitor-ansiedad-escom.onrender.com');
  assert.deepEqual(origenesPermitidos('production'), [ORIGEN_PORTAL]);
  assert.deepEqual(origenesPermitidos('development'), [ORIGEN_PORTAL, 'http://localhost:3000']);
  assert.deepEqual(origenesPermitidos(undefined), [ORIGEN_PORTAL, 'http://localhost:3000']);
});

test('origen permitido: el portal sí; otro sitio no; sin Origin (app nativa) sí', () => {
  const lista = origenesPermitidos('production');
  assert.equal(origenPermitido(ORIGEN_PORTAL, lista), true);
  assert.equal(origenPermitido('https://otro-sitio.com', lista), false);
  assert.equal(origenPermitido('http://localhost:3000', lista), false);
  assert.equal(origenPermitido(undefined, lista), true);
});

test('Socket.io rechaza el handshake de un origen no permitido', async () => {
  const { allowRequest, cors: c } = opcionesSocket(origenesPermitidos('production'));
  assert.deepEqual(c.origin, [ORIGEN_PORTAL]);
  const pedir = (origin) => new Promise((r) => allowRequest({ headers: origin ? { origin } : {} }, (_e, ok) => r(ok)));
  assert.equal(await pedir(ORIGEN_PORTAL), true);
  assert.equal(await pedir('https://malicioso.example.com'), false);
  assert.equal(await pedir(undefined), true);
});

test('valores de los límites: 1000/15 min por IP, 600/15 min por cuenta, 10/h estricto', () => {
  assert.deepEqual(LIMITES.ip, { ventanaMs: 900000, maximo: 1000 });
  assert.deepEqual(LIMITES.usuario, { ventanaMs: 900000, maximo: 600 });
  assert.deepEqual(LIMITES.estricto, { ventanaMs: 3600000, maximo: 10 });
  assert.deepEqual(RUTAS_ESTRICTAS.map(([m, r]) => `${m} ${r}`),
    ['POST /api/usuarios', 'POST /api/especialistas', 'POST /api/consentimiento', 'POST /api/gad7']);
});

// Mini servidor con los mismos middlewares y límites chicos.
async function conServidor(fn) {
  const app = express();
  const limites = crearLimites({
    ip: { ventanaMs: 60000, maximo: 100 },
    usuario: { ventanaMs: 60000, maximo: 3 },
    estricto: { ventanaMs: 60000, maximo: 1 },
  });
  app.use(cors(opcionesCors(origenesPermitidos('production'))));
  app.use('/api', limites.porIp);
  app.use('/api', (req, _res, next) => { req.uid = req.get('x-uid'); next(); }); // hace de requiereAuth
  app.use('/api', limites.porUsuario);
  for (const [m, r] of RUTAS_ESTRICTAS) app[m.toLowerCase()](r, limites.estricto);
  app.post('/api/gad7', (_req, res) => res.status(201).json({ ok: true }));
  app.get('/api/algo', (_req, res) => res.json({ ok: true }));
  const server = app.listen(0);
  await new Promise((r) => server.once('listening', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  try { await fn(base); } finally { server.close(); }
}

test('429 con el formato de error de siempre; el límite es por cuenta', async () => {
  await conServidor(async (base) => {
    const pedir = (uid) => fetch(`${base}/api/algo`, { headers: { 'x-uid': uid } });
    for (let i = 0; i < 3; i++) assert.equal((await pedir('A')).status, 200);
    const r = await pedir('A');
    assert.equal(r.status, 429);
    assert.deepEqual(await r.json(), { error: MENSAJE_429, codigo: CODIGO_429 });
    assert.equal((await pedir('B')).status, 200, 'otra cuenta desde la misma IP no se bloquea');
  });
});

test('el límite estricto aplica a POST /api/gad7', async () => {
  await conServidor(async (base) => {
    const post = () => fetch(`${base}/api/gad7`, { method: 'POST', headers: { 'x-uid': 'C' } });
    assert.equal((await post()).status, 201);
    assert.equal((await post()).status, 429);
  });
});

test('CORS: el portal recibe la cabecera; otro origen no', async () => {
  await conServidor(async (base) => {
    const conOrigen = (origin) => fetch(`${base}/api/algo`, { headers: { origin, 'x-uid': `o-${origin}` } });
    assert.equal((await conOrigen(ORIGEN_PORTAL)).headers.get('access-control-allow-origin'), ORIGEN_PORTAL);
    assert.equal((await conOrigen('https://otro-sitio.com')).headers.get('access-control-allow-origin'), null);
  });
});
