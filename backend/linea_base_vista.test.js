// Pruebas de linea_base_vista.js (Fase M3, paso 2): qué ve cada rol.
// Correr con `npm test` (node --test).
const test = require('node:test');
const assert = require('node:assert/strict');
const { evaluarFilas, calibracionPara } = require('./linea_base_vista');

let siguienteId = 1;

// Igual que en linea_base.test.js: día local de México (UTC−6), numeric como string.
function sesion(dia, hrv, { hora = '08:00', bpm = 72, calidad = 0.9, origen = 'simulacion' } = {}) {
  return {
    id: `v${siguienteId++}`,
    fecha_inicio: new Date(`${dia}T${hora}:00-06:00`).toISOString(),
    origen,
    hrv_rmssd: String(hrv),
    bpm_promedio: String(bpm),
    indice_calidad: String(calidad),
  };
}

// 7 días previos parejos + una sesión muy por debajo el día 8.
const previas = [45, 47, 44, 46, 48, 45, 46].map((hrv, i) => sesion(`2026-10-0${i + 1}`, hrv));
const baja = sesion('2026-10-08', 20, { bpm: 95 });
const sesiones = [...previas, baja];
const ahora = new Date('2026-10-08T20:00:00-06:00');

const CAMPOS_PACIENTE = ['etapa', 'motivo_sin_estado'];

test('paciente: la evaluación trae solo etapa y motivo, nunca la etiqueta', () => {
  const ev = evaluarFilas([baja], sesiones, false).get(baja.id);
  assert.deepEqual(Object.keys(ev).sort(), [...CAMPOS_PACIENTE].sort());
  assert.equal(ev.etapa, 'consolidada');
  assert.equal(ev.motivo_sin_estado, null);
});

test('especialista: la evaluación trae estado, z, FC, n y la banda', () => {
  const ev = evaluarFilas([baja], sesiones, true).get(baja.id);
  assert.equal(ev.estado, 'altos');
  assert.ok(ev.z < -2);
  assert.equal(ev.fc_por_encima, true);
  assert.equal(ev.n, 7);
  assert.equal(ev.banda.n, 7);
  assert.ok(ev.banda.rango_hrv_ms.min < ev.banda.rango_hrv_ms.max);
  assert.ok(ev.banda.de_ln_usada >= 0.10);
  assert.equal(ev.version, 'm3-v1');
});

test('la fila puede venir sin indice_calidad: se evalúa con la de la base', () => {
  // Así llega la lista del paciente (sin la columna interna).
  const { indice_calidad, ...sinCalidad } = baja;
  const ev = evaluarFilas([sinCalidad], sesiones, true).get(baja.id);
  assert.equal(ev.estado, 'altos');
});

test('calibrando: banda null y motivo calibrando', () => {
  const primera = sesion('2026-10-01', 45);
  const ev = evaluarFilas([primera], [primera], true).get(primera.id);
  assert.equal(ev.estado, null);
  assert.equal(ev.motivo_sin_estado, 'calibrando');
  assert.equal(ev.etapa, 'calibrando');
  assert.equal(ev.banda, null);
});

test('calidad baja: sin estado, también para el especialista', () => {
  const mala = sesion('2026-10-08', 45, { calidad: 0.4 });
  const ev = evaluarFilas([mala], [...previas, mala], true).get(mala.id);
  assert.equal(ev.estado, null);
  assert.equal(ev.motivo_sin_estado, 'calidad_baja');
});

test('calibración del paciente: día X de 7 sin banda ni etiqueta', () => {
  const dos = [sesion('2026-10-06', 45), sesion('2026-10-07', 47)];
  const antes = calibracionPara(dos, 'simulacion', false, ahora);
  assert.equal(antes.medido_hoy, false);
  assert.equal(antes.dia_calibracion, 3); // la próxima medición será el día 3
  assert.equal(antes.etapa, 'calibrando');
  assert.equal(antes.etapa_manana, 'calibrando');
  assert.equal('banda' in antes, false);
  assert.equal('n' in antes, false);

  const hoy = sesion('2026-10-08', 46, { hora: '09:00' });
  const despues = calibracionPara([...dos, hoy], 'simulacion', false, ahora);
  assert.equal(despues.medido_hoy, true);
  assert.equal(despues.dia_calibracion, 3); // hoy ya fue su día 3
  assert.equal(despues.etapa_manana, 'preliminar'); // mañana ya se compara
});

test('calibración: día X tope 7 y banda solo al especialista', () => {
  const pac = calibracionPara(sesiones, 'simulacion', false, ahora);
  assert.equal(pac.dia_calibracion, 7);
  assert.equal(pac.etapa, 'consolidada');
  const esp = calibracionPara(sesiones, 'simulacion', true, ahora);
  assert.equal(esp.n, 7);
  assert.ok(esp.banda.rango_hrv_ms.min > 0);
});

test('calibración separada por origen', () => {
  const sensor = calibracionPara(sesiones, 'sensor', true, ahora);
  assert.equal(sensor.dias_con_medicion, 0);
  assert.equal(sensor.dia_calibracion, 1);
  assert.equal(sensor.etapa, 'calibrando');
  assert.equal(sensor.banda, null);
});
