// Pruebas de reporte.js (Bloque 2, paso 4). Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const {
  seudonimo, validarReporte, armarReporte, parametrosReporte, SESIONES_REPORTE, GAD7_REPORTE, MARCADORES_REPORTE,
} = require('./reporte');
const { ValidationError } = require('./errors');

const ok = { desde: '2026-10-01', hasta: '2026-10-31', formato: 'csv', seudonimizado: 'false' };

test('seudónimo: P- + 8 hex del SHA-256 del uid, estable', () => {
  const esperado = `P-${crypto.createHash('sha256').update('uid-123').digest('hex').slice(0, 8)}`;
  assert.equal(seudonimo('uid-123'), esperado);
  assert.match(seudonimo('otro'), /^P-[0-9a-f]{8}$/);
  assert.notEqual(seudonimo('otro'), esperado);
});

test('parámetros: periodo obligatorio, inclusivo, hasta 366 días', () => {
  assert.deepEqual(validarReporte(ok), { desde: '2026-10-01', hasta: '2026-10-31', formato: 'csv', seudonimizado: false });
  assert.equal(validarReporte({ ...ok, seudonimizado: 'true', formato: 'pdf' }).seudonimizado, true);
  assert.doesNotThrow(() => validarReporte({ ...ok, desde: '2025-11-01', hasta: '2026-10-31' })); // 365 días
  assert.throws(() => validarReporte({ ...ok, desde: '2025-01-01', hasta: '2026-10-31' }), /366/);
  assert.throws(() => validarReporte({ ...ok, desde: '2026-11-01' }), /posterior/);
  assert.throws(() => validarReporte({ ...ok, hasta: undefined }), /hasta/);
  assert.throws(() => validarReporte({ ...ok, formato: 'xlsx' }), /formato/);
  assert.throws(() => validarReporte({ ...ok, seudonimizado: '1' }), /seudonimizado/);
  assert.throws(() => validarReporte({ ...ok, paciente: 'x' }), ValidationError);
  assert.throws(() => validarReporte({ ...ok, desde: ['2026-10-01', '2026-10-02'] }), /una sola vez/);
});

test('SQL: por paciente y periodo local; los marcadores, además, por el par', () => {
  for (const sql of [SESIONES_REPORTE, GAD7_REPORTE, MARCADORES_REPORTE]) {
    assert.match(sql, /paciente_id = \$1/);
    assert.match(sql, /AT TIME ZONE \$4/);
    assert.match(sql, /\+ 1\)::timestamp/);
  }
  assert.match(MARCADORES_REPORTE, /especialista_id = \$5/);
  assert.doesNotMatch(SESIONES_REPORTE + GAD7_REPORTE, /especialista_id/);
  assert.deepEqual(parametrosReporte('p', { desde: 'a', hasta: 'b' }), ['p', 'a', 'b', 'America/Mexico_City']);
  // Nada de notas clínicas en el reporte.
  assert.doesNotMatch(SESIONES_REPORTE + GAD7_REPORTE + MARCADORES_REPORTE, /notas_clinicas/);
});

const entrada = (seudonimizado) => ({
  pacienteId: 'uid-123',
  paciente: { nombre: 'Ana Pérez', email: 'ana@ejemplo.com' },
  especialista: { nombre: 'Dra. Uno' },
  filtros: { desde: '2026-10-01', hasta: '2026-10-31', seudonimizado },
  sesiones: [{
    id: 'sesion-uuid', fecha_inicio: '2026-10-05T15:00:00Z', origen: 'sensor', duracion_total_seg: 300,
    duracion_valida_seg: 280, hrv_rmssd: '42.50', bpm_promedio: '71.0', bpm_min: 60, bpm_max: 85, spo2_promedio: '97.0',
    indice_calidad: '0.93', eva_valor: 40, eva_contexto: 'antes_examen', serie: [1, 2],
    evaluacion: { estado: 'normal', etapa: 'consolidada', banda: {} },
  }],
  gad7: [{ id: 'g', fecha_respuesta: '2026-10-10T12:00:00Z', item1: 1, item2: 2, item3: 1, item4: 0, item5: 3, item6: 1, item7: 2 }],
  marcadores: [{ id: 'm', fecha: '2026-10-07T16:00:00Z', tipo: 'periodo_examenes', descripcion: 'Parciales de cálculo' }],
  generadoEn: new Date('2026-11-04T18:00:00Z'),
});

test('reporte con identificación: nombre, correo, especialista y textos', () => {
  const r = armarReporte(entrada(false));
  assert.deepEqual(r.paciente, { id: seudonimo('uid-123'), nombre: 'Ana Pérez', email: 'ana@ejemplo.com' });
  assert.deepEqual(r.especialista, { nombre: 'Dra. Uno' });
  assert.equal(r.sesiones[0].hrv_rmssd, 42.5);
  assert.equal(r.sesiones[0].eva_contexto, 'antes_examen');
  assert.equal(r.sesiones[0].estado, 'normal');
  assert.deepEqual(r.gad7[0], { fecha_respuesta: '2026-10-10T12:00:00Z', puntaje: 10, severidad: 'moderada' });
  assert.equal(r.marcadores[0].descripcion, 'Parciales de cálculo');
  // Campo por campo: ni ids internos ni la serie.
  assert.equal(r.sesiones[0].id, undefined);
  assert.equal(r.sesiones[0].serie, undefined);
  assert.equal(r.generado_en, '2026-11-04T18:00:00.000Z');
});

test('reporte seudonimizado (D3): sin nombre, correo, especialista ni texto libre; con fechas', () => {
  const r = armarReporte(entrada(true));
  const texto = JSON.stringify(r);
  for (const prohibido of ['Ana', 'ana@ejemplo.com', 'Dra. Uno', 'uid-123', 'Parciales', 'antes_examen', 'sesion-uuid']) {
    assert.ok(!texto.includes(prohibido), prohibido);
  }
  assert.deepEqual(r.paciente, { id: seudonimo('uid-123') });
  assert.equal(r.especialista, null);
  assert.equal(r.seudonimizado, true);
  assert.equal(r.sesiones[0].fecha_inicio, '2026-10-05T15:00:00Z');
  assert.ok(!('eva_contexto' in r.sesiones[0]));
  assert.ok(!('descripcion' in r.marcadores[0]));
  assert.equal(r.marcadores[0].tipo, 'periodo_examenes');
});
