// Pruebas de marcadores.js (Bloque 2, paso 3). Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  TIPOS_MARCADOR, DESCRIPCION_MAXIMA, validarMarcadorNuevo, LISTAR_MARCADORES, INSERTAR_MARCADOR, BORRAR_MARCADOR,
} = require('./marcadores');
const { ValidationError } = require('./errors');

const AHORA = new Date('2026-11-04T18:00:00Z');

test('tipos: los mismos del CHECK del DDL (decisión D4)', () => {
  assert.deepEqual([...TIPOS_MARCADOR], ['consulta', 'periodo_examenes', 'evento_personal', 'intervencion', 'otro']);
  assert.ok(Object.isFrozen(TIPOS_MARCADOR));
});

test('marcador válido: fecha normalizada a UTC y descripción recortada o null', () => {
  assert.deepEqual(validarMarcadorNuevo({ fecha: '2026-11-04T10:30:00-06:00', tipo: 'consulta', descripcion: '  Primera cita ' }, AHORA), {
    fecha: '2026-11-04T16:30:00.000Z', tipo: 'consulta', descripcion: 'Primera cita',
  });
  assert.equal(validarMarcadorNuevo({ fecha: '2026-11-04T10:30Z', tipo: 'otro' }, AHORA).descripcion, null);
  assert.equal(validarMarcadorNuevo({ fecha: '2026-11-04T10:30Z', tipo: 'otro', descripcion: '   ' }, AHORA).descripcion, null);
});

test('rechaza tipo desconocido, fecha sin zona o futura, descripción larga y campos extra', () => {
  const ok = { fecha: '2026-11-04T10:30:00Z', tipo: 'consulta' };
  assert.throws(() => validarMarcadorNuevo({ ...ok, tipo: 'examen' }, AHORA), /tipo/);
  assert.throws(() => validarMarcadorNuevo({ ...ok, fecha: '2026-11-04T10:30:00' }, AHORA), /ISO/);
  assert.throws(() => validarMarcadorNuevo({ ...ok, fecha: '2026-11-04' }, AHORA), /ISO/);
  assert.throws(() => validarMarcadorNuevo({ ...ok, fecha: '2026-11-04T18:06:00Z' }, AHORA), /posterior/);
  assert.doesNotThrow(() => validarMarcadorNuevo({ ...ok, fecha: '2026-11-04T18:04:00Z' }, AHORA));
  assert.throws(() => validarMarcadorNuevo({ ...ok, descripcion: 'x'.repeat(DESCRIPCION_MAXIMA + 1) }, AHORA), /140/);
  assert.throws(() => validarMarcadorNuevo({ ...ok, descripcion: 5 }, AHORA), ValidationError);
  assert.throws(() => validarMarcadorNuevo({ ...ok, especialista_id: 'x' }, AHORA), /especialista_id/);
  assert.throws(() => validarMarcadorNuevo('x', AHORA), ValidationError);
});

test('SQL: todo por el par; solo se borra el propio', () => {
  for (const sql of [LISTAR_MARCADORES, BORRAR_MARCADOR]) {
    assert.match(sql, /paciente_id = \$2|paciente_id = \$1/);
    assert.match(sql, /especialista_id = \$\d/);
  }
  assert.match(INSERTAR_MARCADOR, /\(paciente_id, especialista_id, fecha, tipo, descripcion\)/);
  assert.match(BORRAR_MARCADOR, /WHERE id = \$1 AND paciente_id = \$2 AND especialista_id = \$3/);
});
