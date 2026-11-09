'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { rutaSalud } = require('./salud');

test('GET /api/salud responde { ok: true } y nada más', () => {
  const res = {
    cabeceras: {},
    set(k, v) { this.cabeceras[k] = v; return this; },
    status(c) { this.codigo = c; return this; },
    json(b) { this.cuerpo = b; return this; },
  };
  rutaSalud({}, res);
  assert.equal(res.codigo, 200);
  assert.deepEqual(res.cuerpo, { ok: true });
  assert.equal(res.cabeceras['Cache-Control'], 'no-store');
});
