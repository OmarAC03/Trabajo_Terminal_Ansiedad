// Pruebas de dispositivos.js (Bloque 3). Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  MAXIMO_POR_CUENTA, validarToken, REGISTRAR_TOKEN, RECORTAR_TOKENS, BORRAR_TOKEN_PROPIO, CONTAR_TOKENS,
  BORRAR_TOKENS_DE_CUENTA,
} = require('./dispositivos');
const { ValidationError } = require('./errors');

const TOKEN = 'fcm-token-de-prueba-0123456789:APA91b';

test('token válido', () => {
  assert.equal(validarToken({ token: TOKEN }), TOKEN);
});

test('rechaza token ausente, corto, largo, con espacios o campos de más', () => {
  for (const body of [
    null, [], 'x', {}, { token: 5 }, { token: 'corto' }, { token: 'x'.repeat(4097) },
    { token: `${TOKEN} con espacio` }, { token: TOKEN, usuario_id: 'otro' },
  ]) {
    assert.throws(() => validarToken(body), ValidationError, JSON.stringify(body));
  }
});

test('SQL: el token se reasigna al aparato de la cuenta nueva y se recorta a 5', () => {
  assert.equal(MAXIMO_POR_CUENTA, 5);
  assert.match(REGISTRAR_TOKEN, /ON CONFLICT \(token\) DO UPDATE SET usuario_id = EXCLUDED\.usuario_id/);
  assert.match(RECORTAR_TOKENS, /LIMIT 5/);
  assert.match(RECORTAR_TOKENS, /usuario_id = \$1/);
});

test('SQL: borrar solo lo propio; contar nunca devuelve tokens', () => {
  assert.match(BORRAR_TOKEN_PROPIO, /token = \$1 AND usuario_id = \$2/);
  assert.doesNotMatch(CONTAR_TOKENS, /SELECT token|SELECT \*/);
  assert.match(BORRAR_TOKENS_DE_CUENTA, /^DELETE FROM dispositivos_push WHERE usuario_id = \$1$/);
});
