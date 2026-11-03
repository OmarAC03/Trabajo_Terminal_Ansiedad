import {
  MENSAJES_BLOQUEO, codigoBloqueo, guardarAvisoCierre, tomarAvisoCierre, accionEstado, consecuencias,
} from './cuentas';

const error = (status, data) => ({ response: { status, data } });
const fila = (extra = {}) => ({ id: 'u1', rol: 'paciente', estado: 'activa', ...extra });

test('codigoBloqueo reconoce solo los 403 con código de cuenta', () => {
  expect(codigoBloqueo(error(403, { error: 'x', codigo: 'cuenta_suspendida' }))).toBe('cuenta_suspendida');
  expect(codigoBloqueo(error(403, { error: 'x', codigo: 'cuenta_eliminada' }))).toBe('cuenta_eliminada');
  expect(codigoBloqueo(error(403, { error: 'No autorizado' }))).toBeNull();
  expect(codigoBloqueo(error(401, { codigo: 'cuenta_suspendida' }))).toBeNull();
  expect(codigoBloqueo(error(403, { codigo: 'toString' }))).toBeNull();
  expect(codigoBloqueo(new Error('Network Error'))).toBeNull();
  expect(codigoBloqueo(undefined)).toBeNull();
});

test('cada código de bloqueo tiene su mensaje', () => {
  expect(MENSAJES_BLOQUEO.cuenta_suspendida).toMatch(/suspendida/);
  expect(MENSAJES_BLOQUEO.cuenta_eliminada).toMatch(/eliminada/);
});

test('el aviso de cierre se toma una sola vez', () => {
  guardarAvisoCierre('Tu cuenta está suspendida.');
  expect(tomarAvisoCierre()).toBe('Tu cuenta está suspendida.');
  expect(tomarAvisoCierre()).toBe('');
  guardarAvisoCierre(undefined);
  expect(tomarAvisoCierre()).toBe('');
});

test('accionEstado: activa → suspender, suspendida → reactivar', () => {
  expect(accionEstado(fila(), 'admin')).toEqual({ accion: 'suspender', motivo: null });
  expect(accionEstado(fila({ estado: 'suspendida' }), 'admin')).toEqual({ accion: 'reactivar', motivo: null });
});

test('accionEstado: la propia cuenta no se suspende y una eliminada no se toca', () => {
  expect(accionEstado(fila({ id: 'admin', rol: 'admin' }), 'admin').accion).toBeNull();
  expect(accionEstado(fila({ id: 'admin', rol: 'admin' }), 'admin').motivo).toMatch(/propia/);
  expect(accionEstado(fila({ estado: 'eliminada' }), 'admin').accion).toBeNull();
  expect(accionEstado(fila({ estado: 'eliminada' }), 'admin').motivo).toMatch(/eliminada/);
});

test('consecuencias: al suspender a un especialista se avisa de sus pacientes', () => {
  expect(consecuencias('suspender', fila()).join(' ')).not.toMatch(/pacientes/);
  expect(consecuencias('suspender', fila({ rol: 'especialista' })).join(' ')).toMatch(/pacientes siguen vinculados/);
  expect(consecuencias('suspender', fila()).join(' ')).toMatch(/No se borra ningún dato/);
  expect(consecuencias('reactivar', fila())).toHaveLength(1);
  expect(consecuencias(null, fila())).toEqual([]);
});
