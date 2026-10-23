// Pruebas de gad7.js y validarGad7 (Fase M5a). Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const { CONFIG_GAD7, puntaje, severidad, valorar, estadoGad7, itemsDeFila } = require('./gad7');
const { validarGad7 } = require('./validation');

// Instante en hora de México (UTC−6, sin horario de verano desde 2022).
const mx = (dia, hora = '12:00') => new Date(`${dia}T${hora}:00-06:00`);

// --- Puntaje y severidad ---

test('el puntaje es la suma de los 7 ítems (0–21)', () => {
  assert.equal(puntaje([0, 0, 0, 0, 0, 0, 0]), 0);
  assert.equal(puntaje([1, 2, 3, 0, 1, 2, 3]), 12);
  assert.equal(puntaje([3, 3, 3, 3, 3, 3, 3]), 21);
});

test('el puntaje exige exactamente 7 ítems', () => {
  assert.throws(() => puntaje([1, 2, 3]));
  assert.throws(() => puntaje(null));
});

test('severidad en las fronteras 4/5, 9/10 y 14/15', () => {
  const casos = [
    [0, 'minima'], [4, 'minima'],
    [5, 'leve'], [9, 'leve'],
    [10, 'moderada'], [14, 'moderada'],
    [15, 'grave'], [21, 'grave'],
  ];
  for (const [p, esperada] of casos) assert.equal(severidad(p), esperada, `puntaje ${p}`);
});

test('severidad fuera de 0–21 es un error (nunca una etiqueta inventada)', () => {
  assert.throws(() => severidad(-1));
  assert.throws(() => severidad(22));
});

test('"valorar" desde 10 (frontera 9/10)', () => {
  assert.equal(valorar(9), false);
  assert.equal(valorar(10), true);
  assert.equal(valorar(21), true);
});

test('itemsDeFila lee item1…item7 en orden', () => {
  const fila = { item1: 0, item2: 1, item3: 2, item4: 3, item5: 0, item6: 1, item7: 2 };
  assert.deepEqual(itemsDeFila(fila), [0, 1, 2, 3, 0, 1, 2]);
});

// --- ¿Le toca responder? (14 días por fecha local) ---

test('si nunca respondió, le toca hoy', () => {
  assert.deepEqual(estadoGad7(null, mx('2026-10-22')), {
    toca: true, proxima_fecha: '2026-10-22', dias_restantes: 0,
  });
});

test('al día siguiente de responder faltan 13 días; el día 14 le vuelve a tocar', () => {
  const respondio = mx('2026-10-01', '10:00');
  assert.deepEqual(estadoGad7(respondio, mx('2026-10-01', '18:00')), {
    toca: false, proxima_fecha: '2026-10-15', dias_restantes: 14,
  });
  assert.equal(estadoGad7(respondio, mx('2026-10-02')).dias_restantes, 13);
  assert.equal(estadoGad7(respondio, mx('2026-10-14')).toca, false);
  assert.deepEqual(estadoGad7(respondio, mx('2026-10-15', '09:00')), {
    toca: true, proxima_fecha: '2026-10-15', dias_restantes: 0,
  });
});

test('cambio de día a medianoche: 23:59 del día 14 aún no, 00:00 del día 15 sí', () => {
  const respondio = mx('2026-10-01', '23:59'); // tarde: sigue siendo el día 1 en México
  assert.equal(estadoGad7(respondio, mx('2026-10-14', '23:59')).toca, false);
  assert.equal(estadoGad7(respondio, mx('2026-10-14', '23:59')).dias_restantes, 1);
  assert.equal(estadoGad7(respondio, mx('2026-10-15', '00:00')).toca, true);
});

test('cuenta el día de México, no el de UTC', () => {
  // 23:30 en México del día 1 = 05:30 UTC del día 2: el GAD-7 es del día 1.
  const respondio = new Date('2026-10-02T05:30:00Z');
  assert.equal(estadoGad7(respondio, mx('2026-10-14', '20:00')).proxima_fecha, '2026-10-15');
  // Y "ahora" también es local: 00:30 del 15 en México es 06:30 UTC del 15.
  assert.equal(estadoGad7(respondio, new Date('2026-10-15T06:30:00Z')).toca, true);
  // 23:00 del 14 en México ya es día 15 en UTC, pero aquí todavía no toca.
  assert.equal(estadoGad7(respondio, new Date('2026-10-15T05:00:00Z')).toca, false);
});

test('si dejó pasar más de 14 días, le toca y la próxima fecha es hoy', () => {
  const e = estadoGad7(mx('2026-09-01'), mx('2026-10-22'));
  assert.deepEqual(e, { toca: true, proxima_fecha: '2026-10-22', dias_restantes: 0 });
});

test('el intervalo cruza fin de mes', () => {
  assert.equal(estadoGad7(mx('2026-10-25'), mx('2026-10-26')).proxima_fecha, '2026-11-08');
});

test('la versión del texto es gad7-es-v1 y el intervalo, 14 días', () => {
  assert.equal(CONFIG_GAD7.version, 'gad7-es-v1');
  assert.equal(CONFIG_GAD7.intervaloDias, 14);
});

// --- validarGad7 ---

const valido = { items: [0, 1, 2, 3, 0, 1, 2] };

test('acepta 7 respuestas de 0 a 3, con o sin dificultad', () => {
  assert.deepEqual(validarGad7(valido), { items: [0, 1, 2, 3, 0, 1, 2], dificultad: null });
  assert.deepEqual(validarGad7({ ...valido, dificultad: 2 }), { items: valido.items, dificultad: 2 });
  assert.deepEqual(validarGad7({ ...valido, dificultad: null }).dificultad, null);
});

test('rechaza paciente_id, puntaje, version o cualquier otro campo', () => {
  for (const extra of [{ paciente_id: 'x' }, { puntaje: 7 }, { version: 'gad7-es-v1' }, { severidad: 'leve' }]) {
    assert.throws(() => validarGad7({ ...valido, ...extra }), { statusCode: 400 }, JSON.stringify(extra));
  }
});

test('rechaza items que no sean 7 enteros de 0 a 3', () => {
  const malos = [
    undefined,
    [0, 1, 2],
    [0, 1, 2, 3, 0, 1, 2, 3],
    [0, 1, 2, 4, 0, 1, 2],
    [0, 1, 2, -1, 0, 1, 2],
    [0, 1, 2, 1.5, 0, 1, 2],
    [0, 1, 2, '1', 0, 1, 2],
    [0, 1, 2, null, 0, 1, 2],
    '0123012',
  ];
  for (const items of malos) {
    assert.throws(() => validarGad7({ items }), { statusCode: 400 }, JSON.stringify(items));
  }
});

test('rechaza dificultad fuera de 0–3 o que no sea entero', () => {
  for (const dificultad of [4, -1, 1.5, '2', true]) {
    assert.throws(() => validarGad7({ ...valido, dificultad }), { statusCode: 400 }, JSON.stringify(dificultad));
  }
});

test('rechaza un cuerpo que no sea objeto', () => {
  for (const body of [null, [], 'items', 7]) {
    assert.throws(() => validarGad7(body), { statusCode: 400 });
  }
});
