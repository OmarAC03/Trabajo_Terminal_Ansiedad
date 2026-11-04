import {
  campoCsv, csvDesdeReporte, nombreArchivo, fechaLocal, rangoPorDefecto, errorRango, parametrosReporte, reporteUrl,
} from './reporte';

const reporte = (seudonimizado) => ({
  seudonimizado,
  paciente: seudonimizado ? { id: 'P-1a2b3c4d' } : { id: 'P-1a2b3c4d', nombre: 'Ana', email: 'ana@x.com' },
  periodo: { desde: '2026-10-01', hasta: '2026-10-31', zona_horaria: 'America/Mexico_City' },
  generado_en: '2026-11-04T18:00:00.000Z',
  sesiones: [{
    fecha_inicio: '2026-10-05T15:00:00Z', origen: 'sensor', duracion_total_seg: 300, duracion_valida_seg: 280,
    hrv_rmssd: 42.5, bpm_promedio: 71, bpm_min: 60, bpm_max: 85, spo2_promedio: 97, indice_calidad: 0.93,
    eva_valor: 40, ...(seudonimizado ? {} : { eva_contexto: 'antes_examen' }), estado: 'normal', etapa: 'consolidada',
  }],
  gad7: [{ fecha_respuesta: '2026-10-10T12:00:00Z', puntaje: 10, severidad: 'moderada' }],
  marcadores: [{ fecha: '2026-10-07T16:00:00Z', tipo: 'otro', ...(seudonimizado ? {} : { descripcion: '=HYPERLINK("x")' }) }],
});

test('campo CSV: comillas, números tal cual y sin inyección de fórmulas', () => {
  expect(campoCsv('hola')).toBe('"hola"');
  expect(campoCsv('dijo "sí", luego')).toBe('"dijo ""sí"", luego"');
  expect(campoCsv('=SUM(A1)')).toBe('"\'=SUM(A1)"');
  for (const peligroso of ['+1', '-1+2', '@cmd', '\tx', '\rx']) expect(campoCsv(peligroso).startsWith('"\'')).toBe(true);
  expect(campoCsv(-3)).toBe('-3');
  expect(campoCsv(42.5)).toBe('42.5');
  expect(campoCsv(null)).toBe('');
  expect(campoCsv(NaN)).toBe('');
  expect(campoCsv(true)).toBe('true');
});

test('CSV largo: BOM, encabezado, CRLF y una fila por dato', () => {
  const csv = csvDesdeReporte(reporte(false));
  expect(csv.startsWith('﻿"paciente","registro","fecha_utc","fecha_local","variable","valor","unidad"\r\n')).toBe(true);
  const lineas = csv.slice(1).trim().split('\r\n');
  // encabezado + nombre y correo + 13 variables de sesión + 2 de GAD-7 + 2 del marcador
  expect(lineas).toHaveLength(1 + 2 + 13 + 2 + 2);
  expect(lineas[1]).toBe('"P-1a2b3c4d","paciente",,,"nombre","Ana",');
  expect(lineas[2]).toBe('"P-1a2b3c4d","paciente",,,"email","ana@x.com",');
  expect(lineas).toContain('"P-1a2b3c4d","sesion","2026-10-05T15:00:00Z","2026-10-05 09:00","hrv_rmssd",42.5,"ms"');
  expect(lineas).toContain('"P-1a2b3c4d","gad7","2026-10-10T12:00:00Z","2026-10-10 06:00","puntaje",10,"0-21"');
  // La descripción con fórmula queda neutralizada.
  expect(csv).toContain('"\'=HYPERLINK(""x"")"');
});

test('CSV seudonimizado: sin contexto EVA ni descripción (no vienen del backend)', () => {
  const csv = csvDesdeReporte(reporte(true));
  expect(csv).not.toMatch(/eva_contexto|descripcion|HYPERLINK|"paciente","paciente"|nombre|email/);
  expect(csv).toMatch(/"marcador","2026-10-07T16:00:00Z","2026-10-07 10:00","tipo","otro"/);
});

test('nombre de archivo con el identificador, nunca el nombre', () => {
  expect(nombreArchivo(reporte(false), 'csv')).toBe('reporte_P-1a2b3c4d_2026-10-01_2026-10-31.csv');
  expect(nombreArchivo(reporte(true), 'csv')).toBe('reporte_P-1a2b3c4d_2026-10-01_2026-10-31_seudonimizado.csv');
});

test('fechas, periodo y parámetros', () => {
  expect(fechaLocal('2026-10-05T15:00:00Z')).toBe('2026-10-05 09:00');
  expect(fechaLocal(null)).toBe('');
  expect(rangoPorDefecto(new Date('2026-11-04T18:00:00Z'))).toEqual({ desde: '2026-10-06', hasta: '2026-11-04' });
  expect(errorRango({ desde: '2026-10-01', hasta: '2026-10-31' })).toBe('');
  expect(errorRango({ desde: '2026-11-01', hasta: '2026-10-31' })).toMatch(/posterior/);
  expect(errorRango({ desde: '2025-01-01', hasta: '2026-10-31' })).toMatch(/366/);
  expect(errorRango({ desde: '', hasta: '2026-10-31' })).toMatch(/periodo/);
  expect(parametrosReporte({ desde: 'a', hasta: 'b' }, 'pdf', true)).toEqual({ desde: 'a', hasta: 'b', formato: 'pdf', seudonimizado: 'true' });
  expect(reporteUrl('p1')).toMatch(/\/api\/pacientes\/p1\/reporte$/);
});
