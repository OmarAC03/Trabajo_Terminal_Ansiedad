'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { CUENTAS_AISLAMIENTO, PREFIJO_MENSAJE, sqlVerificar, sqlLimpiar } = require('./semilla_aislamiento');
const { CONFIG_CONSENTIMIENTO } = require('../consentimiento');

const leer = (archivo) => fs.readFileSync(path.join(__dirname, archivo), 'utf8');

test('B y F son cuentas PRUEBA con correos @example.com (nunca reales)', () => {
  for (const c of Object.values(CUENTAS_AISLAMIENTO)) {
    assert.match(c.nombre, /^PRUEBA - /);
    assert.match(c.email, /@example\.com$/);
  }
  assert.equal(CUENTAS_AISLAMIENTO.B.rol, 'paciente');
  assert.equal(CUENTAS_AISLAMIENTO.F.rol, 'especialista');
});

test('prueba_aislamiento.ps1 usa los mismos nombres y correos que la semilla', () => {
  const ps1 = leer('prueba_aislamiento.ps1');
  for (const c of Object.values(CUENTAS_AISLAMIENTO)) {
    assert.ok(ps1.includes(`nombre = '${c.nombre}'`), c.nombre);
    assert.ok(ps1.includes(`email = '${c.email}'`), c.email);
  }
  assert.ok(ps1.includes(`LIKE '${PREFIJO_MENSAJE}%'`));
});

test('los .ps1 mandan las versiones vigentes del consentimiento', () => {
  for (const archivo of ['prueba_aislamiento.ps1', 'prueba_cuentas.ps1']) {
    const ps1 = leer(archivo);
    assert.ok(ps1.includes(`version_aviso = '${CONFIG_CONSENTIMIENTO.version_aviso}'`), archivo);
    assert.ok(ps1.includes(`version_consentimiento = '${CONFIG_CONSENTIMIENTO.version_consentimiento}'`), archivo);
  }
});

test('el SQL de verificar es de solo lectura y el de limpiar solo borra los mensajes de la prueba', () => {
  const ver = sqlVerificar();
  assert.match(ver, /^\s*(--.*\n)*\s*SELECT/m);
  assert.doesNotMatch(ver, /\b(INSERT|UPDATE|DELETE|ALTER|DROP|TRUNCATE)\b/i);
  const limpiar = sqlLimpiar();
  assert.match(limpiar, /DELETE FROM mensajes_chat WHERE texto LIKE 'PRUEBA aislamiento%';/);
  assert.equal((limpiar.match(/DELETE/g) || []).length, 1);
});

test('socket.io-client solo en devDependencies', () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8'));
  assert.ok(pkg.devDependencies['socket.io-client']);
  assert.equal(pkg.dependencies['socket.io-client'], undefined);
});
