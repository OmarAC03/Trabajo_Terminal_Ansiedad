// Pruebas de eliminacion.js (Bloque 1, paso 3). Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  BORRADO_PACIENTE,
  NOMBRE_ELIMINADA,
  ANONIMIZAR_USUARIO,
  emailAnonimo,
  parametrosAnonimizar,
  validarSolicitudNueva,
  verificarAtencion,
  vistaSolicitudPaciente,
} = require('./eliminacion');
const { ValidationError, HttpError } = require('./errors');

const tablas = BORRADO_PACIENTE.map((p) => p.tabla);

test('se borran las tablas clínicas y de comunicación, y ninguna más', () => {
  assert.deepEqual([...tablas].sort(), [
    'dispositivos_push',
    'ejercicios_asignados',
    'lecturas_biometricas',
    'marcadores_clinicos',
    'mensajes_chat',
    'notas_clinicas',
    'respuestas_eva',
    'respuestas_gad7',
    'sesiones_medicion',
  ]);
});

test('lo que se conserva (usuarios, consentimientos, solicitudes) no se borra', () => {
  for (const conservada of ['usuarios', 'consentimientos', 'solicitudes_eliminacion', 'bitacora']) {
    assert.ok(!tablas.includes(conservada), conservada);
    for (const paso of BORRADO_PACIENTE) {
      assert.doesNotMatch(paso.sql, new RegExp(`DELETE FROM ${conservada}\\b`));
    }
  }
});

test('el orden respeta las FK: la EVA antes que sus sesiones', () => {
  assert.ok(tablas.indexOf('respuestas_eva') < tablas.indexOf('sesiones_medicion'));
  assert.equal(tablas[0], 'respuestas_eva');
});

test('cada borrado es un DELETE limitado al paciente ($1)', () => {
  for (const paso of BORRADO_PACIENTE) {
    assert.match(paso.sql, new RegExp(`^DELETE FROM ${paso.tabla} WHERE `));
    assert.match(paso.sql, /(paciente_id|usuario_id) = \$1/);
  }
  // Los mensajes por paciente_id: cubre los dos sentidos de su conversación.
  assert.match(BORRADO_PACIENTE.find((p) => p.tabla === 'mensajes_chat').sql, /WHERE paciente_id = \$1$/);
  assert.ok(Object.isFrozen(BORRADO_PACIENTE));
});

test('la lápida no conserva nombre, correo, código ni especialista', () => {
  assert.match(ANONIMIZAR_USUARIO, /nombre = \$2/);
  assert.match(ANONIMIZAR_USUARIO, /email = \$3/);
  assert.match(ANONIMIZAR_USUARIO, /codigo_vinculacion = NULL/);
  assert.match(ANONIMIZAR_USUARIO, /especialista_id = NULL/);
  assert.match(ANONIMIZAR_USUARIO, /eliminado_en = now\(\)/);
  assert.match(ANONIMIZAR_USUARIO, /WHERE id = \$1/);
  assert.deepEqual(parametrosAnonimizar('abc123'), ['abc123', NOMBRE_ELIMINADA, 'eliminada-abc123@invalid']);
});

test('el correo anónimo es único por cuenta y cabe en varchar(100)', () => {
  const uid = 'x'.repeat(50); // usuarios.id es varchar(50)
  assert.ok(emailAnonimo(uid).length <= 100);
  assert.notEqual(emailAnonimo('a'), emailAnonimo('b'));
  assert.match(emailAnonimo('a'), /@invalid$/);
});

test('la solicitud nueva no lleva datos', () => {
  assert.doesNotThrow(() => validarSolicitudNueva(undefined));
  assert.doesNotThrow(() => validarSolicitudNueva(null));
  assert.doesNotThrow(() => validarSolicitudNueva({}));
  for (const body of [{ motivo: 'ya no la uso' }, { usuario_id: 'otro' }, [], 'si', 7]) {
    assert.throws(() => validarSolicitudNueva(body), (e) => e instanceof ValidationError && e.statusCode === 400);
  }
});

test('solo se atienden cuentas de paciente', () => {
  assert.doesNotThrow(() => verificarAtencion({ rol: 'paciente' }));
  for (const rol of ['especialista', 'admin']) {
    assert.throws(() => verificarAtencion({ rol }), (e) => e instanceof HttpError && e.statusCode === 409);
  }
  assert.throws(() => verificarAtencion(undefined), (e) => e instanceof HttpError && e.statusCode === 409);
});

test('el paciente ve el estado y las fechas de su solicitud, nada más', () => {
  assert.equal(vistaSolicitudPaciente(undefined), null);
  const fecha = new Date('2026-11-03T20:00:00Z');
  assert.deepEqual(vistaSolicitudPaciente({ estado: 'pendiente', fecha_solicitud: fecha, atendida_por: 'admin' }), {
    estado: 'pendiente',
    fecha_solicitud: fecha,
    atendida_en: null,
  });
});
