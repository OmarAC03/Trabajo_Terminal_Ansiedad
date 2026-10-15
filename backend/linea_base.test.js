// Pruebas de linea_base.js (Fase M3). Correr con `npm test` (node --test).
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  CONFIG_LINEA_BASE,
  diaLocal,
  lineaBaseAntesDe,
  evaluarSesion,
  evaluarSesiones,
  progresoCalibracion,
} = require('./linea_base');

let siguienteId = 1;

// Sesión del día local `dia` a la hora local `hora` (México es UTC−6 todo el
// año). Los numeric van como string, igual que los devuelve pg.
function sesion(dia, hrv, { hora = '08:00', bpm = 72, calidad = 0.9, origen = 'simulacion' } = {}) {
  return {
    id: `s${siguienteId++}`,
    fecha_inicio: new Date(`${dia}T${hora}:00-06:00`).toISOString(),
    origen,
    hrv_rmssd: String(hrv),
    bpm_promedio: String(bpm),
    indice_calidad: String(calidad),
  };
}

// Días consecutivos terminando en `ultimo`, uno por valor de HRV.
function diasSeguidos(ultimo, hrvs, opciones) {
  return hrvs.map((hrv, i) => {
    const d = new Date(`${ultimo}T12:00:00Z`);
    d.setUTCDate(d.getUTCDate() - (hrvs.length - 1 - i));
    return sesion(d.toISOString().slice(0, 10), hrv, opciones);
  });
}

const cerca = (real, esperado, tol = 1e-9) => assert.ok(
  Math.abs(real - esperado) < tol, `esperaba ${esperado}, salió ${real}`,
);

test('el día se toma en hora de México, no en UTC', () => {
  // 02:00 UTC del 14 = 20:00 del 13 en México.
  assert.equal(diaLocal('2026-10-14T02:00:00Z', 'America/Mexico_City'), '2026-10-13');
  assert.equal(diaLocal('2026-10-14T06:00:00Z', 'America/Mexico_City'), '2026-10-14');
});

test('con 0, 1 o 2 días no hay estado (calibrando)', () => {
  for (let n = 0; n <= 2; n++) {
    const previas = diasSeguidos('2026-10-09', [45, 47, 44].slice(0, n));
    const actual = sesion('2026-10-10', 30);
    const r = evaluarSesion(actual, [...previas, actual]);
    assert.equal(r.estado, null);
    assert.equal(r.motivo_sin_estado, 'calibrando');
    assert.equal(r.linea_base.etapa, 'calibrando');
    assert.equal(r.linea_base.n, n);
  }
});

test('con 3 días la base es preliminar y k1 = 1.5; con 7, consolidada y k1 = 1.0', () => {
  const tres = lineaBaseAntesDe(diasSeguidos('2026-10-09', [45, 47, 44]), '2026-10-10', 'simulacion');
  assert.equal(tres.etapa, 'preliminar');
  cerca(tres.k1, 1.5);
  cerca(tres.k2, 2.5);

  const cinco = lineaBaseAntesDe(diasSeguidos('2026-10-09', [45, 47, 44, 46, 48]), '2026-10-10', 'simulacion');
  cerca(cinco.k1, 1.25);

  const siete = lineaBaseAntesDe(diasSeguidos('2026-10-09', [45, 47, 44, 46, 48, 43, 45]), '2026-10-10', 'simulacion');
  assert.equal(siete.etapa, 'consolidada');
  cerca(siete.k1, 1.0);
  cerca(siete.k2, 2.0);
});

test('la ventana usa solo los últimos 7 días con medición', () => {
  // 10 días: los 3 primeros (muy bajos) quedan fuera de la ventana.
  const previas = diasSeguidos('2026-10-09', [10, 10, 10, 45, 47, 44, 46, 48, 43, 45]);
  const base = lineaBaseAntesDe(previas, '2026-10-10', 'simulacion');
  assert.equal(base.n, 7);
  assert.deepEqual(base.dias, ['2026-10-03', '2026-10-04', '2026-10-05', '2026-10-06', '2026-10-07', '2026-10-08', '2026-10-09']);
  cerca(base.media_ln, [45, 47, 44, 46, 48, 43, 45].reduce((s, v) => s + Math.log(v), 0) / 7);
});

test('el día de la sesión no entra en su propia base', () => {
  const previas = diasSeguidos('2026-10-09', [45, 47]);
  const tempranoHoy = sesion('2026-10-10', 46, { hora: '07:00' });
  const actual = sesion('2026-10-10', 30, { hora: '20:00' });
  const r = evaluarSesion(actual, [...previas, tempranoHoy, actual]);
  assert.equal(r.linea_base.n, 2); // la de la mañana de hoy no cuenta
  assert.equal(r.estado, null);
});

test('varias sesiones el mismo día se promedian y el día cuenta una vez', () => {
  const previas = [
    sesion('2026-10-07', 40, { hora: '08:00' }),
    sesion('2026-10-07', 50, { hora: '19:00' }),
    sesion('2026-10-08', 45),
  ];
  const base = lineaBaseAntesDe(previas, '2026-10-10', 'simulacion');
  assert.equal(base.n, 2);
  assert.equal(base.etapa, 'calibrando');

  const conTercerDia = [...previas, sesion('2026-10-09', 45)];
  const b3 = lineaBaseAntesDe(conTercerDia, '2026-10-10', 'simulacion');
  assert.equal(b3.n, 3);
  const dia7 = (Math.log(40) + Math.log(50)) / 2;
  cerca(b3.media_ln, (dia7 + Math.log(45) + Math.log(45)) / 3);
});

test('con días casi iguales se usa el piso de la DE (0.10 Ln)', () => {
  const previas = diasSeguidos('2026-10-09', [45, 45, 45]);
  const base = lineaBaseAntesDe(previas, '2026-10-10', 'simulacion');
  cerca(base.de_ln, 0);
  cerca(base.de_ln_usada, CONFIG_LINEA_BASE.pisoDeLn);
  // Sin piso, una HRV de 44 (z = −∞ con DE 0) saldría "Altos"; con piso es Normal.
  const actual = sesion('2026-10-10', 44);
  assert.equal(evaluarSesion(actual, [...previas, actual]).estado, 'normal');
});

test('clasificación por z: Normal / Elevados / Altos, y por encima de la banda es Normal', () => {
  // Base de 7 días iguales: media = ln 45, DE = piso 0.10, k1 = 1, k2 = 2.
  const previas = diasSeguidos('2026-10-09', [45, 45, 45, 45, 45, 45, 45]);
  const conZ = (z) => {
    const actual = sesion('2026-10-10', 45 * Math.exp(z * 0.10));
    return evaluarSesion(actual, [...previas, actual]);
  };
  assert.equal(conZ(-0.99).estado, 'normal');
  assert.equal(conZ(-1.01).estado, 'elevados');
  assert.equal(conZ(-1.99).estado, 'elevados');
  assert.equal(conZ(-2.01).estado, 'altos');
  assert.equal(conZ(+3).estado, 'normal');
  cerca(conZ(-1.5).z, -1.5, 1e-3);
});

test('la banda preliminar es más tolerante que la consolidada', () => {
  // Misma caída (z ≈ −1.2): Elevados con base consolidada, Normal con 3 días.
  const tres = diasSeguidos('2026-10-09', [45, 45, 45]);
  const siete = diasSeguidos('2026-10-09', [45, 45, 45, 45, 45, 45, 45]);
  const actual = sesion('2026-10-10', 45 * Math.exp(-1.2 * 0.10));
  assert.equal(evaluarSesion(actual, [...tres, actual]).estado, 'normal');
  assert.equal(evaluarSesion(actual, [...siete, actual]).estado, 'elevados');
});

test('la FC solo acompaña: marca fc_por_encima pero no cambia el estado', () => {
  const previas = diasSeguidos('2026-10-09', [45, 45, 45, 45, 45, 45, 45], { bpm: 70 });
  const fcAlta = sesion('2026-10-10', 45, { bpm: 90 });
  const r = evaluarSesion(fcAlta, [...previas, fcAlta]);
  assert.equal(r.estado, 'normal');
  assert.equal(r.fc_por_encima, true);
  cerca(r.linea_base.fc.de_usada, CONFIG_LINEA_BASE.pisoDeBpm);

  const fcNormal = sesion('2026-10-10', 45, { bpm: 71 });
  assert.equal(evaluarSesion(fcNormal, [...previas, fcNormal]).fc_por_encima, false);
});

test('la base se separa por origen: el sensor no usa días de simulación', () => {
  const simuladas = diasSeguidos('2026-10-09', [45, 47, 44, 46, 48, 43, 45]);
  const sensor = sesion('2026-10-10', 30, { origen: 'sensor' });
  const r = evaluarSesion(sensor, [...simuladas, sensor]);
  assert.equal(r.linea_base.n, 0);
  assert.equal(r.motivo_sin_estado, 'calibrando');
});

test('los días de hace más de 30 días vencen', () => {
  const viejas = diasSeguidos('2026-09-05', [45, 47, 44, 46]); // 2–5 sep
  const actual = sesion('2026-10-10', 30);
  const r = evaluarSesion(actual, [...viejas, actual]);
  assert.equal(r.linea_base.n, 0);
  assert.equal(r.estado, null);

  // Justo 30 días antes todavía cuenta.
  const limite = lineaBaseAntesDe([sesion('2026-09-10', 45)], '2026-10-10', 'simulacion');
  assert.equal(limite.n, 1);
  const fuera = lineaBaseAntesDe([sesion('2026-09-09', 45)], '2026-10-10', 'simulacion');
  assert.equal(fuera.n, 0);
});

test('calidad baja: no entra a la base ni recibe estado', () => {
  const previas = diasSeguidos('2026-10-09', [45, 47, 44]);
  const ruidosa = sesion('2026-10-08', 10, { hora: '20:00', calidad: 0.45 });
  const base = lineaBaseAntesDe([...previas, ruidosa], '2026-10-10', 'simulacion');
  cerca(base.media_ln, (Math.log(45) + Math.log(47) + Math.log(44)) / 3);

  const actualRuidosa = sesion('2026-10-10', 20, { calidad: 0.59 });
  const r = evaluarSesion(actualRuidosa, [...previas, actualRuidosa]);
  assert.equal(r.estado, null);
  assert.equal(r.motivo_sin_estado, 'calidad_baja');

  const enElLimite = sesion('2026-10-10', 45, { calidad: 0.6 });
  assert.equal(evaluarSesion(enElLimite, [...previas, enElLimite]).estado, 'normal');
});

test('evaluarSesiones evalúa cada sesión contra su propia base histórica', () => {
  const todas = diasSeguidos('2026-10-10', [45, 47, 44, 46, 48]);
  const r = evaluarSesiones(todas);
  assert.deepEqual(r.map((x) => x.linea_base.n), [0, 1, 2, 3, 4]);
  assert.deepEqual(r.map((x) => x.linea_base.etapa), ['calibrando', 'calibrando', 'calibrando', 'preliminar', 'preliminar']);
});

test('progresoCalibracion: días medidos, sesiones de hoy y etapa de la próxima medición', () => {
  const ahora = new Date('2026-10-10T18:00:00-06:00');
  const vacio = progresoCalibracion([], 'simulacion', ahora);
  assert.equal(vacio.dias_con_medicion, 0);
  assert.equal(vacio.etapa, 'calibrando');

  const tres = [...diasSeguidos('2026-10-09', [45, 47]), sesion('2026-10-10', 44), sesion('2026-10-10', 46, { hora: '12:00' })];
  const p = progresoCalibracion(tres, 'simulacion', ahora);
  assert.equal(p.hoy, '2026-10-10');
  assert.equal(p.dias_con_medicion, 3);
  assert.equal(p.sesiones_validas_hoy, 2);
  assert.equal(p.etapa, 'preliminar'); // mañana ya compara contra 3 días
  assert.equal(p.dias_en_base, 3);

  const vencido = progresoCalibracion([sesion('2026-09-01', 45)], 'simulacion', ahora);
  assert.equal(vencido.dias_con_medicion, 0);
  assert.equal(vencido.hay_historial_vencido, true);
});
