// Pruebas de gad7_vista.js (Fase M5a): qué ve cada rol. Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const { vistaGad7, guardadaParaPaciente, estadoPara } = require('./gad7_vista');

let siguienteId = 1;

// Una fila como la devuelve `pg` de respuestas_gad7 (smallint llega como número).
function fila(dia, items, { dificultad = null, hora = '10:00' } = {}) {
  const f = {
    id: `g${siguienteId++}`,
    paciente_id: 'paciente-1',
    dificultad,
    version: 'gad7-es-v1',
    fecha_respuesta: new Date(`${dia}T${hora}:00-06:00`).toISOString(),
  };
  items.forEach((v, i) => { f[`item${i + 1}`] = v; });
  return f;
}

const vieja = fila('2026-09-20', [1, 1, 1, 1, 0, 0, 0]); // 4 → mínima
const reciente = fila('2026-10-10', [2, 2, 2, 1, 1, 1, 3], { dificultad: 2 }); // 12 → moderada, valorar
const filas = [vieja, reciente];
const ahora = new Date('2026-10-22T12:00:00-06:00');

const CAMPOS_ESTADO = ['toca', 'proxima_fecha', 'dias_restantes', 'ultima_respuesta', 'intervalo_dias', 'vinculado'];

// Nada de esto puede aparecer en lo que recibe el paciente (claves ni valores).
const PROHIBIDAS = [
  'puntaje', 'severidad', 'item', 'items', 'dificultad', 'valorar', 'version',
  'minima', 'leve', 'moderada', 'grave', 'normal', 'elevados', 'altos',
];

function assertSinPalabrasProhibidas(objeto) {
  const texto = JSON.stringify(objeto).toLowerCase();
  for (const palabra of PROHIBIDAS) {
    assert.ok(!texto.includes(`"${palabra}`), `el paciente recibió "${palabra}": ${texto}`);
  }
}

test('paciente: solo el estado, con sus 5 campos y nada más', () => {
  const v = vistaGad7(filas, false, true, ahora);
  assert.deepEqual(Object.keys(v), ['estado']);
  assert.deepEqual(Object.keys(v.estado).sort(), [...CAMPOS_ESTADO].sort());
  assert.deepEqual(v.estado, {
    toca: false,
    proxima_fecha: '2026-10-24',
    dias_restantes: 2,
    ultima_respuesta: reciente.fecha_respuesta,
    intervalo_dias: 14,
    vinculado: true,
  });
});

test('paciente: ninguna palabra prohibida, ni con resultado grave ni sin respuestas', () => {
  const grave = fila('2026-10-21', [3, 3, 3, 3, 3, 3, 3], { dificultad: 3 });
  for (const lista of [filas, [grave], []]) {
    assertSinPalabrasProhibidas(vistaGad7(lista, false, true, ahora));
  }
  assertSinPalabrasProhibidas(guardadaParaPaciente(grave, [grave], ahora));
});

test('paciente sin respuestas: le toca hoy y no hay última respuesta', () => {
  assert.deepEqual(vistaGad7([], false, true, ahora).estado, {
    toca: true,
    proxima_fecha: '2026-10-22',
    dias_restantes: 0,
    ultima_respuesta: null,
    intervalo_dias: 14,
    vinculado: true,
  });
});

test('especialista: estado + historial completo, del más reciente al más viejo', () => {
  const v = vistaGad7(filas, true, true, ahora);
  assert.deepEqual(v.estado, vistaGad7(filas, false, true, ahora).estado);
  assert.deepEqual(v.respuestas.map((r) => r.id), [reciente.id, vieja.id]);
  assert.deepEqual(v.respuestas[0], {
    id: reciente.id,
    fecha_respuesta: reciente.fecha_respuesta,
    version: 'gad7-es-v1',
    items: [2, 2, 2, 1, 1, 1, 3],
    dificultad: 2,
    puntaje: 12,
    severidad: 'moderada',
    valorar: true,
  });
  assert.equal(v.respuestas[1].puntaje, 4);
  assert.equal(v.respuestas[1].severidad, 'minima');
  assert.equal(v.respuestas[1].valorar, false);
  assert.equal(v.respuestas[1].dificultad, null);
});

test('una columna nueva en la tabla no se filtra a ningún rol', () => {
  const conExtra = { ...reciente, nota_interna: 'secreta', paciente_id: 'paciente-1' };
  const texto = JSON.stringify([vistaGad7([conExtra], false, true, ahora), vistaGad7([conExtra], true, true, ahora)]);
  assert.ok(!texto.includes('nota_interna'));
  assert.ok(!texto.includes('paciente_id'));
});

test('guardada (POST): id, fecha y el nuevo estado, ya sin tocarle', () => {
  const nueva = fila('2026-10-22', [0, 0, 1, 0, 0, 0, 0]);
  const g = guardadaParaPaciente(nueva, [...filas, nueva], ahora);
  assert.deepEqual(Object.keys(g), ['id', 'fecha_respuesta', 'estado']);
  assert.equal(g.estado.toca, false);
  assert.equal(g.estado.proxima_fecha, '2026-11-05');
  assert.equal(g.estado.dias_restantes, 14);
});

test('el estado toma la respuesta más reciente aunque las filas vengan desordenadas', () => {
  assert.equal(estadoPara([reciente, vieja], true, ahora).ultima_respuesta, reciente.fecha_respuesta);
  assert.equal(estadoPara([vieja, reciente], true, ahora).ultima_respuesta, reciente.fecha_respuesta);
});

test('paciente sin especialista: vinculado false (la app no muestra la tarjeta)', () => {
  const e = vistaGad7([], false, false, ahora).estado;
  assert.equal(e.vinculado, false);
  assert.equal(e.toca, true); // el intervalo no depende del vínculo; el POST sí lo exige
  assertSinPalabrasProhibidas(vistaGad7([], false, false, ahora));
});

test('la respuesta del POST siempre es de un paciente vinculado', () => {
  const nueva = fila('2026-10-22', [0, 0, 0, 0, 0, 0, 0]);
  assert.equal(guardadaParaPaciente(nueva, [nueva], ahora).estado.vinculado, true);
});
