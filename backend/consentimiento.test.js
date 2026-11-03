// Pruebas de consentimiento.js (Bloque 1, paso 2). Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  CONFIG_CONSENTIMIENTO,
  CODIGO_CONSENTIMIENTO_REQUERIDO,
  requiereConsentimiento,
  validarConsentimiento,
  exigirConsentimiento,
  vistaConsentimiento,
} = require('./consentimiento');
const { ValidationError, AuthError } = require('./errors');

const vigente = () => ({ ...CONFIG_CONSENTIMIENTO });
const es400 = (fn) => assert.throws(fn, (e) => e instanceof ValidationError && e.statusCode === 400);

test('las versiones vigentes son las del borrador (VERIFICAR) y coinciden con la app', () => {
  // Si cambian aquí, cambiar también privacidad_textos.dart en la app.
  assert.equal(CONFIG_CONSENTIMIENTO.version_aviso, 'privacidad-v0-borrador');
  assert.equal(CONFIG_CONSENTIMIENTO.version_consentimiento, 'consentimiento-v0-borrador');
  assert.ok(Object.isFrozen(CONFIG_CONSENTIMIENTO));
});

test('solo el paciente requiere consentimiento', () => {
  assert.equal(requiereConsentimiento('paciente'), true);
  for (const rol of ['especialista', 'admin', null, undefined]) {
    assert.equal(requiereConsentimiento(rol), false);
  }
});

test('validarConsentimiento acepta exactamente la versión vigente', () => {
  assert.deepEqual(validarConsentimiento(vigente()), vigente());
});

test('una versión vieja o distinta de cualquiera de los dos textos → 400', () => {
  es400(() => validarConsentimiento({ ...vigente(), version_aviso: 'privacidad-v-1' }));
  es400(() => validarConsentimiento({ ...vigente(), version_consentimiento: 'consentimiento-v9' }));
});

test('faltan campos, sobran campos o tipos equivocados → 400', () => {
  es400(() => validarConsentimiento({ version_aviso: CONFIG_CONSENTIMIENTO.version_aviso }));
  es400(() => validarConsentimiento({ ...vigente(), aceptado_en: '2026-01-01' }));
  es400(() => validarConsentimiento({ ...vigente(), usuario_id: 'otro' }));
  es400(() => validarConsentimiento({ ...vigente(), version_aviso: 7 }));
  es400(() => validarConsentimiento({ ...vigente(), version_aviso: '   ' }));
  for (const body of [null, undefined, [], 'si', true]) {
    es400(() => validarConsentimiento(body));
  }
});

test('exigirConsentimiento: paciente sin el vigente → 403 consentimiento_requerido', () => {
  assert.throws(
    () => exigirConsentimiento('paciente', false),
    (e) => e instanceof AuthError && e.statusCode === 403 && e.codigo === CODIGO_CONSENTIMIENTO_REQUERIDO
  );
  assert.equal(CODIGO_CONSENTIMIENTO_REQUERIDO, 'consentimiento_requerido');
});

test('exigirConsentimiento: paciente con el vigente, o cualquier otro rol, pasa', () => {
  assert.doesNotThrow(() => exigirConsentimiento('paciente', true));
  // Las rutas de captura ya rechazan otros roles por su cuenta; aquí no se
  // pide consentimiento a quien no es paciente.
  assert.doesNotThrow(() => exigirConsentimiento('especialista', false));
  assert.doesNotThrow(() => exigirConsentimiento('admin', false));
});

test('vistaConsentimiento: paciente que aún no acepta', () => {
  assert.deepEqual(vistaConsentimiento('paciente', null), {
    requerido: true,
    ...vigente(),
    aceptado: false,
    aceptado_en: null,
  });
});

test('vistaConsentimiento: paciente que ya aceptó la vigente', () => {
  const fecha = new Date('2026-11-03T18:00:00Z');
  const v = vistaConsentimiento('paciente', fecha);
  assert.equal(v.aceptado, true);
  assert.equal(v.aceptado_en, fecha);
});

test('vistaConsentimiento: especialista y admin no lo requieren', () => {
  for (const rol of ['especialista', 'admin']) {
    const v = vistaConsentimiento(rol, new Date());
    assert.equal(v.requerido, false);
    assert.equal(v.aceptado, false);
    assert.equal(v.aceptado_en, null);
  }
});
