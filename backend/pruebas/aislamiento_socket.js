// Parte Socket.io de prueba_aislamiento.ps1 (Fase S, d). PowerShell 5.1 no
// tiene cliente de Socket.io; este script usa socket.io-client (MIT, solo en
// devDependencies) contra el backend LOCAL. Los tokens llegan por variables de
// entorno (nunca por argumentos ni se imprimen):
//   AISL_BASE, AISL_TOKEN_A, AISL_TOKEN_B, AISL_TOKEN_E, AISL_TOKEN_F, AISL_UID_A, AISL_SELLO
// Imprime una línea "[OK] ..." o "[FALLA] ..." por caso y sale con el número
// de fallas como código.

const { io } = require('socket.io-client');
const { PREFIJO_MENSAJE } = require('./semilla_aislamiento');

const env = process.env;
const BASE = env.AISL_BASE || 'http://localhost:3000';
const ESPERA_MS = 5000;
let fallas = 0;

function caso(nombre, bien, detalle = '') {
  if (bien) console.log(`[OK]    ${nombre}`);
  else {
    fallas++;
    console.log(`[FALLA] ${nombre}${detalle ? ` -> ${detalle}` : ''}`);
  }
}

// Conecta y resuelve con el socket, o con { error } si el handshake se rechaza.
function conectar(token, opciones = {}) {
  return new Promise((resolve) => {
    const socket = io(BASE, {
      auth: token ? { token } : {},
      transports: opciones.transports || ['websocket'],
      extraHeaders: opciones.extraHeaders,
      reconnection: false,
      timeout: 15000,
      forceNew: true,
    });
    socket.once('connect', () => resolve({ socket }));
    socket.once('connect_error', (err) => {
      socket.close();
      resolve({ error: err.message || String(err) });
    });
  });
}

const enviar = (socket, datos) =>
  new Promise((resolve) => {
    const t = setTimeout(() => resolve({ ok: null, error: 'sin respuesta' }), ESPERA_MS);
    socket.emit('enviar_mensaje', datos, (r) => {
      clearTimeout(t);
      resolve(r || {});
    });
  });

// Junta lo que recibe un socket en 'recibir_mensaje'.
function escuchar(socket) {
  const recibidos = [];
  socket.on('recibir_mensaje', (m) => recibidos.push(m));
  return recibidos;
}

const esperar = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const uidA = env.AISL_UID_A;
  const sello = env.AISL_SELLO || String(Date.now());

  // S1. Sin token no hay conexión.
  const sinToken = await conectar(null);
  caso('S1 handshake sin token: rechazado', Boolean(sinToken.error), sinToken.error ? '' : 'se conectó');
  if (sinToken.socket) sinToken.socket.close();

  // S2. Otro origen (navegador de un sitio ajeno): rechazado aunque traiga token.
  const ajeno = await conectar(env.AISL_TOKEN_B, {
    transports: ['polling'],
    extraHeaders: { Origin: 'https://sitio-ajeno.example.com' },
  });
  caso('S2 handshake desde otro origen: rechazado', Boolean(ajeno.error), ajeno.error ? '' : 'se conectó');
  if (ajeno.socket) ajeno.socket.close();

  const cA = await conectar(env.AISL_TOKEN_A);
  const cB = await conectar(env.AISL_TOKEN_B);
  const cE = await conectar(env.AISL_TOKEN_E);
  const cF = await conectar(env.AISL_TOKEN_F);
  for (const [n, c] of [['A', cA], ['B', cB], ['E', cE], ['F', cF]]) {
    caso(`S0 ${n} se conecta con su token`, Boolean(c.socket), c.error);
  }
  if (!cA.socket || !cB.socket || !cE.socket || !cF.socket) {
    for (const c of [cA, cB, cE, cF]) if (c.socket) c.socket.close();
    process.exit(fallas || 1);
  }

  const deB = escuchar(cB.socket);
  const deF = escuchar(cF.socket);
  const deE = escuchar(cE.socket);

  // S3/S4. B (otro paciente) y F (especialista no vinculado) no pueden
  // escribir en la conversación de A.
  const rB = await enviar(cB.socket, { paciente_id: uidA, texto: `${PREFIJO_MENSAJE} ${sello} (B no debería poder)` });
  caso('S3 B escribe en el canal de A: rechazado', rB.ok === false, JSON.stringify(rB));
  const rF = await enviar(cF.socket, { paciente_id: uidA, texto: `${PREFIJO_MENSAJE} ${sello} (F no debería poder)` });
  caso('S4 F escribe en el canal de A: rechazado', rF.ok === false, JSON.stringify(rF));

  // S5. A escribe en su conversación: lo recibe E (control) y NI B NI F.
  const texto = `${PREFIJO_MENSAJE} ${sello} (A a su especialista)`;
  const rA = await enviar(cA.socket, { paciente_id: uidA, texto });
  caso('S5 A escribe en su propio canal (control)', rA.ok === true, JSON.stringify(rA));
  await esperar(ESPERA_MS);
  const llegoA = (lista) => lista.some((m) => m && m.texto === texto);
  caso('S6 E (su especialista) recibe el mensaje de A (control)', llegoA(deE));
  caso('S7 B NO recibe el mensaje de A', !llegoA(deB) && deB.length === 0, `recibió ${deB.length}`);
  caso('S8 F NO recibe el mensaje de A', !llegoA(deF) && deF.length === 0, `recibió ${deF.length}`);

  for (const c of [cA, cB, cE, cF]) c.socket.close();
  process.exit(fallas);
}

main().catch((err) => {
  console.log(`[FALLA] error inesperado -> ${err.message}`);
  process.exit(1);
});
