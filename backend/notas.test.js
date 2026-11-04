// Pruebas de notas.js (Bloque 2, paso 2). Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  CONTENIDO_MAXIMO, diaValido, validarNotaNueva, validarEdicionNota, decidirEdicion,
  LISTAR_NOTAS, BLOQUEAR_NOTA, EXISTE_NOTA, GUARDAR_VERSION_ANTERIOR, ACTUALIZAR_NOTA,
} = require('./notas');
const { ValidationError, HttpError } = require('./errors');

// 4 nov 2026, 23:30 en Ciudad de México (ya es 5 nov en UTC).
const AHORA = new Date('2026-11-05T05:30:00Z');

test('días válidos', () => {
  assert.equal(diaValido('2026-11-04'), true);
  assert.equal(diaValido('2026-02-30'), false);
  assert.equal(diaValido('2026-11-4'), false);
  assert.equal(diaValido(20261104), false);
});

test('nota nueva: recorta el texto y acepta hoy en hora local', () => {
  assert.deepEqual(validarNotaNueva({ fecha: '2026-11-04', contenido: '  Refiere mejor sueño.  ' }, AHORA), {
    fecha: '2026-11-04', contenido: 'Refiere mejor sueño.',
  });
});

test('nota nueva: rechaza fecha futura (día local), vacía, larga o con campos extra', () => {
  assert.throws(() => validarNotaNueva({ fecha: '2026-11-05', contenido: 'x' }, AHORA), /posterior a hoy/);
  assert.throws(() => validarNotaNueva({ fecha: '1999-12-31', contenido: 'x' }, AHORA), ValidationError);
  assert.throws(() => validarNotaNueva({ fecha: '2026-11-04', contenido: '   ' }, AHORA), /vacía/);
  assert.throws(() => validarNotaNueva({ fecha: '2026-11-04', contenido: 'x'.repeat(CONTENIDO_MAXIMO + 1) }, AHORA), /5000/);
  assert.throws(() => validarNotaNueva({ fecha: '2026-11-04', contenido: 'x', paciente_id: 'otro' }, AHORA), /paciente_id/);
  assert.throws(() => validarNotaNueva(null, AHORA), ValidationError);
  assert.throws(() => validarNotaNueva([], AHORA), ValidationError);
});

test('el largo cuenta caracteres, no unidades UTF-16 (como char_length)', () => {
  const emojis = '🙂'.repeat(CONTENIDO_MAXIMO);
  assert.equal(validarNotaNueva({ fecha: '2026-11-04', contenido: emojis }, AHORA).contenido, emojis);
});

test('edición: exige la versión que se tenía en pantalla', () => {
  const base = { fecha: '2026-11-03', contenido: 'Texto' };
  assert.equal(validarEdicionNota({ ...base, version: 2 }, AHORA).version, 2);
  for (const version of [undefined, 0, -1, 1.5, '2']) {
    assert.throws(() => validarEdicionNota({ ...base, version }, AHORA), /version/);
  }
  assert.throws(() => validarEdicionNota({ ...base, version: 1, especialista_id: 'x' }, AHORA), /especialista_id/);
});

test('decidirEdicion: 409 si cambió, false si no hay cambios', () => {
  const actual = { version: 3, fecha: '2026-11-03', contenido: 'A' };
  assert.throws(
    () => decidirEdicion(actual, { version: 2, fecha: '2026-11-03', contenido: 'B' }),
    (e) => e instanceof HttpError && e.statusCode === 409 && e.codigo === 'nota_desactualizada'
  );
  assert.equal(decidirEdicion(actual, { version: 3, fecha: '2026-11-03', contenido: 'A' }), false);
  assert.equal(decidirEdicion(actual, { version: 3, fecha: '2026-11-02', contenido: 'A' }), true);
  assert.equal(decidirEdicion(actual, { version: 3, fecha: '2026-11-03', contenido: 'B' }), true);
});

test('SQL: todo se filtra por el par paciente–especialista (D1)', () => {
  for (const sql of [LISTAR_NOTAS, BLOQUEAR_NOTA, EXISTE_NOTA]) {
    assert.match(sql, /paciente_id = \$\d/);
    assert.match(sql, /especialista_id = \$\d/);
  }
  assert.match(BLOQUEAR_NOTA, /FOR UPDATE/);
  // La versión que se guarda es la vigente, antes de actualizarla.
  assert.match(GUARDAR_VERSION_ANTERIOR, /INSERT INTO notas_clinicas_versiones/);
  assert.match(ACTUALIZAR_NOTA, /version = version \+ 1/);
  // Nunca se borra una nota (D6).
  for (const sql of [LISTAR_NOTAS, BLOQUEAR_NOTA, GUARDAR_VERSION_ANTERIOR, ACTUALIZAR_NOTA]) {
    assert.doesNotMatch(sql, /DELETE/);
  }
});
