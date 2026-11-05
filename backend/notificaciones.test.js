// Pruebas de notificaciones.js (Bloque 3). Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  TITULO, TEXTOS, TIPOS, CODIGOS_TOKEN_INVALIDO, mensajeFcm, tokensAInvalidar, otrosErrores, colaToken,
  TOKENS_DE_PACIENTE, BORRAR_TOKENS, crearNotificador,
} = require('./notificaciones');

const T1 = 'token-uno-aaaaaaaaaaaaaaaaaaaa';
const T2 = 'token-dos-bbbbbbbbbbbbbbbbbbbb';
const T3 = 'token-tres-cccccccccccccccccccc';

const ok = () => ({ success: true, messageId: 'm' });
const falla = (code) => ({ success: false, error: { code, message: code } });

// Base y messaging falsos; se anota todo lo que se pidió.
function falsos({ tokens = [T1, T2], respuestas, errorEnvio, errorBase } = {}) {
  const consultas = [];
  const enviados = [];
  const logs = { info: [], error: [] };
  const pool = {
    query: async (sql, params) => {
      consultas.push({ sql, params });
      if (errorBase) throw errorBase;
      return /SELECT d\.token/.test(sql) ? { rows: tokens.map((token) => ({ token })) } : { rows: [], rowCount: 0 };
    },
  };
  const messaging = () => ({
    sendEachForMulticast: async (mensaje) => {
      enviados.push(mensaje);
      if (errorEnvio) throw errorEnvio;
      const responses = respuestas || mensaje.tokens.map(ok);
      return {
        responses,
        successCount: responses.filter((r) => r.success).length,
        failureCount: responses.filter((r) => !r.success).length,
      };
    },
  });
  const logger = { info: (m, d) => logs.info.push({ m, d }), error: (m, d) => logs.error.push({ m, d }) };
  return { notificador: crearNotificador({ pool, messaging, logger }), consultas, enviados, logs };
}

test('regla de oro: textos fijos, neutros y sin datos', () => {
  assert.equal(TITULO, 'Monitor ESCOM');
  assert.deepEqual({ ...TEXTOS }, {
    mensaje: 'Tienes un mensaje nuevo de tu especialista',
    ejercicio: 'Tu especialista te asignó un ejercicio',
  });
  assert.ok(Object.isFrozen(TEXTOS));
  assert.deepEqual([...TIPOS], ['mensaje', 'ejercicio']);
});

test('el mensaje de FCM solo lleva el texto fijo y el tipo', () => {
  const m = mensajeFcm('mensaje', [T1]);
  assert.deepEqual(m.notification, { title: TITULO, body: TEXTOS.mensaje });
  assert.deepEqual(m.data, { tipo: 'mensaje' });
  assert.equal(m.android.priority, 'high');
  assert.equal(m.android.notification.tag, 'mensaje');
  assert.throws(() => mensajeFcm('gad7', [T1]), /tipo desconocido/);
  assert.throws(() => mensajeFcm('Hola, ¿cómo sigues?', [T1]), /tipo desconocido/);
});

test('avisar: el contenido del chat no aparece en nada de lo que se envía', async () => {
  const { notificador, enviados } = falsos();
  await notificador.avisar('pac-1', 'mensaje');
  const texto = JSON.stringify(enviados);
  for (const prohibido of ['pac-1', 'ansiedad', 'GAD', 'puntaje']) assert.ok(!texto.includes(prohibido), prohibido);
  assert.deepEqual(enviados[0].tokens, [T1, T2]);
});

test('solo se borran los tokens que FCM da por inexistentes o inválidos', () => {
  const tokens = [T1, T2, T3];
  const respuesta = { responses: [
    falla('messaging/registration-token-not-registered'),
    falla('messaging/invalid-argument'),
    falla('messaging/invalid-registration-token'),
  ] };
  assert.deepEqual(tokensAInvalidar(tokens, respuesta), [T1, T3]);
  assert.deepEqual(otrosErrores(tokens, respuesta), { 'messaging/invalid-argument': 1 });
  assert.deepEqual([...CODIGOS_TOKEN_INVALIDO].sort(), [
    'messaging/invalid-registration-token', 'messaging/registration-token-not-registered',
  ]);
});

test('avisar: borra los inválidos y conserva los que fallaron por otra causa', async () => {
  const { notificador, consultas, logs } = falsos({
    tokens: [T1, T2, T3],
    respuestas: [ok(), falla('messaging/registration-token-not-registered'), falla('messaging/quota-exceeded')],
  });
  const r = await notificador.avisar('pac-1', 'ejercicio');
  assert.deepEqual(r, { enviados: 1, fallidos: 2, invalidados: 1 });
  const borrado = consultas.find((c) => c.sql === BORRAR_TOKENS);
  assert.deepEqual(borrado.params, [[T2]]);
  assert.equal(logs.error.length, 1);
  assert.deepEqual(logs.error[0].d.codigos, { 'messaging/quota-exceeded': 1 });
  // Al log nunca va un token completo.
  assert.ok(!JSON.stringify(logs).includes(T2));
});

test('avisar: un error de red o de credenciales no borra nada ni lanza', async () => {
  const error = Object.assign(new Error('socket hang up'), { code: 'app/network-error' });
  const { notificador, consultas, logs } = falsos({ errorEnvio: error });
  const r = await notificador.avisar('pac-1', 'mensaje');
  assert.deepEqual(r, { enviados: 0, fallidos: 0, invalidados: 0 });
  assert.ok(!consultas.some((c) => c.sql === BORRAR_TOKENS));
  assert.equal(logs.error[0].d.codigo, 'app/network-error');
});

test('avisar: sin tokens no llama a FCM; si falla la base, no lanza', async () => {
  const vacio = falsos({ tokens: [] });
  await vacio.notificador.avisar('pac-1', 'mensaje');
  assert.equal(vacio.enviados.length, 0);

  const caida = falsos({ errorBase: new Error('sin conexión') });
  await assert.doesNotReject(caida.notificador.avisar('pac-1', 'mensaje'));
  assert.equal(caida.logs.error.length, 1);
});

test('solo pacientes activos reciben: la consulta excluye suspendidos y eliminados', () => {
  assert.match(TOKENS_DE_PACIENTE, /u\.rol = 'paciente'/);
  assert.match(TOKENS_DE_PACIENTE, /NOT u\.suspendido/);
  assert.match(TOKENS_DE_PACIENTE, /u\.eliminado_en IS NULL/);
  assert.equal(colaToken(T1), '…aaaaaa');
});
