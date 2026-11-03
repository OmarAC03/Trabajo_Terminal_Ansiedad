// Pruebas de cuentas.js (Bloque 1, paso 1: suspender / reactivar). Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const { CODIGO_SUSPENDIDA, CODIGO_ELIMINADA, bloqueoDeCuenta, verificarCambioSuspension } = require('./cuentas');
const { AuthError, HttpError } = require('./errors');

const ADMIN = 'uid-admin';
const cuenta = (extra = {}) => ({ id: 'uid-x', rol: 'paciente', suspendido: false, eliminado_en: null, ...extra });

// Lanza HttpError 409 con el mensaje esperado.
const rechaza = (fn, texto) =>
  assert.throws(fn, (e) => e instanceof HttpError && e.statusCode === 409 && e.message.includes(texto));

// --- Bloqueo de acceso (lo usa requiereAuth / requiereAuthSocket) ---

test('una cuenta activa no se bloquea', () => {
  assert.equal(bloqueoDeCuenta(cuenta()), null);
});

test('sin fila en usuarios (registro en curso) no se bloquea', () => {
  assert.equal(bloqueoDeCuenta(null), null);
  assert.equal(bloqueoDeCuenta(undefined), null);
});

test('una cuenta suspendida se bloquea con cuenta_suspendida', () => {
  const b = bloqueoDeCuenta(cuenta({ suspendido: true }));
  assert.equal(b.codigo, CODIGO_SUSPENDIDA);
  assert.equal(b.codigo, 'cuenta_suspendida');
  assert.match(b.mensaje, /suspendida/);
});

test('una cuenta eliminada se bloquea con cuenta_eliminada, aunque además esté suspendida', () => {
  const fecha = new Date('2026-11-01T12:00:00Z');
  assert.equal(bloqueoDeCuenta(cuenta({ eliminado_en: fecha })).codigo, CODIGO_ELIMINADA);
  assert.equal(bloqueoDeCuenta(cuenta({ eliminado_en: fecha, suspendido: true })).codigo, 'cuenta_eliminada');
});

test('el mensaje de bloqueo no dice nada clínico', () => {
  for (const c of [cuenta({ suspendido: true }), cuenta({ eliminado_en: new Date() })]) {
    assert.doesNotMatch(bloqueoDeCuenta(c).mensaje, /sesi[oó]n de medici|lectura|gad|eva|ansiedad/i);
  }
});

// --- El código viaja en el error (lo pone el middleware en la respuesta) ---

test('AuthError y HttpError llevan el código solo si se lo dan', () => {
  assert.equal(new AuthError('x', 403, 'cuenta_suspendida').codigo, 'cuenta_suspendida');
  assert.equal(new AuthError('x', 403).codigo, undefined);
  assert.equal(new AuthError('x').statusCode, 401);
  assert.equal(new HttpError('x', 409, 'otro').codigo, 'otro');
  assert.equal(new HttpError('x', 409).codigo, undefined);
});

// --- Candados de suspensión ---

test('el admin puede suspender a un paciente o a un especialista', () => {
  for (const rol of ['paciente', 'especialista']) {
    assert.doesNotThrow(() =>
      verificarCambioSuspension({ adminUid: ADMIN, objetivo: cuenta({ rol }), suspender: true, otrosAdminsActivos: 0 })
    );
  }
});

test('nadie puede suspender su propia cuenta', () => {
  rechaza(
    () => verificarCambioSuspension({ adminUid: ADMIN, objetivo: cuenta({ id: ADMIN, rol: 'admin' }), suspender: true, otrosAdminsActivos: 3 }),
    'propia'
  );
});

test('no se puede suspender al último admin activo', () => {
  rechaza(
    () => verificarCambioSuspension({ adminUid: ADMIN, objetivo: cuenta({ id: 'otro-admin', rol: 'admin' }), suspender: true, otrosAdminsActivos: 0 }),
    'último administrador'
  );
});

test('sí se puede suspender a otro admin si queda al menos uno activo', () => {
  assert.doesNotThrow(() =>
    verificarCambioSuspension({ adminUid: ADMIN, objetivo: cuenta({ id: 'otro-admin', rol: 'admin' }), suspender: true, otrosAdminsActivos: 1 })
  );
});

test('una cuenta eliminada no se suspende ni se reactiva', () => {
  const eliminada = cuenta({ eliminado_en: new Date() });
  for (const suspender of [true, false]) {
    rechaza(() => verificarCambioSuspension({ adminUid: ADMIN, objetivo: eliminada, suspender, otrosAdminsActivos: 1 }), 'eliminada');
  }
});

test('reactivar no pasa por los candados de "propia" ni de "último admin"', () => {
  assert.doesNotThrow(() =>
    verificarCambioSuspension({ adminUid: ADMIN, objetivo: cuenta({ id: 'otro-admin', rol: 'admin', suspendido: true }), suspender: false, otrosAdminsActivos: 0 })
  );
});

test('repetir la acción (ya suspendida / ya activa) se permite: es idempotente', () => {
  assert.doesNotThrow(() =>
    verificarCambioSuspension({ adminUid: ADMIN, objetivo: cuenta({ suspendido: true }), suspender: true, otrosAdminsActivos: 0 })
  );
  assert.doesNotThrow(() =>
    verificarCambioSuspension({ adminUid: ADMIN, objetivo: cuenta(), suspender: false, otrosAdminsActivos: 0 })
  );
});
