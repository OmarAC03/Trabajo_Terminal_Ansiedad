import {
  normalizarSesion, resumenSesiones, datosTendencia, serieConCortes, huecosDeSerie,
  porcentajeCalidad, minSeg, duracionTexto, fechaHora,
} from './sesiones';

// Fila como la manda el backend al especialista: numeric como texto.
const fila = (id, fechaIso, extra = {}) => ({
  id,
  fecha_inicio: fechaIso,
  duracion_total_seg: 214,
  duracion_valida_seg: 180,
  hrv_rmssd: '42.46',
  hrv_min: '38.50',
  hrv_max: '49.10',
  bpm_promedio: '73.2',
  bpm_min: 70,
  bpm_max: 76,
  spo2_promedio: '97.4',
  spo2_min: 96,
  spo2_max: 99,
  indice_calidad: '0.841',
  origen: 'simulacion',
  ...extra,
});

describe('normalizarSesion', () => {
  test('convierte los numeric que llegan como texto', () => {
    const s = normalizarSesion(fila('a', '2026-10-13T15:30:00Z'));
    expect(s.hrv_rmssd).toBe(42.46);
    expect(s.bpm_promedio).toBe(73.2);
    expect(s.indice_calidad).toBe(0.841);
    expect(s.bpm_min).toBe(70);
    expect(s.origen).toBe('simulacion');
  });

  test('normaliza y ordena la serie si viene', () => {
    const s = normalizarSesion(fila('a', '2026-10-13T15:30:00Z', {
      serie: [{ t: 10, bpm: 74, spo2: 97, hrv: 41 }, { t: 0, bpm: '73', spo2: 97, hrv: '40.5' }],
    }));
    expect(s.serie.map((p) => p.t)).toEqual([0, 10]);
    expect(s.serie[0].hrv).toBe(40.5);
  });

  test('sin serie (lista) no inventa una', () => {
    expect(normalizarSesion(fila('a', '2026-10-13T15:30:00Z')).serie).toBeUndefined();
  });
});

describe('resumenSesiones y datosTendencia', () => {
  const ahora = new Date('2026-10-13T18:00:00Z').getTime();
  const sesiones = [
    fila('hoy', '2026-10-13T15:30:00Z', { hrv_rmssd: '40', bpm_promedio: '70' }),
    fila('hace10', '2026-10-03T15:30:00Z', { hrv_rmssd: '50', bpm_promedio: '80' }),
    fila('hace40', '2026-09-03T15:30:00Z', { hrv_rmssd: '90', bpm_promedio: '60' }),
  ].map(normalizarSesion);

  test('solo cuenta los últimos 30 días, pero la última es la más reciente de todas', () => {
    const r = resumenSesiones(sesiones, { ahora });
    expect(r.total).toBe(2);
    expect(r.hrvPromedio).toBe(45);
    expect(r.bpmPromedio).toBe(75);
    expect(r.ultima).toBe('2026-10-13T15:30:00Z');
  });

  test('sin sesiones: total 0 y promedios null (no 0)', () => {
    const r = resumenSesiones([], { ahora });
    expect(r).toEqual({ total: 0, hrvPromedio: null, bpmPromedio: null, ultima: null });
  });

  test('la tendencia va de la más antigua a la más reciente y deja fuera las de más de 30 días', () => {
    const datos = datosTendencia(sesiones, { ahora });
    expect(datos.map((d) => d.hrv)).toEqual([50, 40]);
    expect(datos[1].bpm).toBe(70);
  });
});

describe('serie con huecos (vista del especialista)', () => {
  const serie = [
    { t: 0, bpm: 72, spo2: 97, hrv: 40 },
    { t: 5, bpm: 73, spo2: 97, hrv: 41 },
    { t: 25, bpm: 74, spo2: 98, hrv: 42 }, // hueco de 10 a 25
    { t: 30, bpm: 75, spo2: 98, hrv: 43 },
  ];

  test('inserta un punto null donde hay hueco para que la línea se corte', () => {
    const conCortes = serieConCortes(serie);
    expect(conCortes.map((p) => p.t)).toEqual([0, 5, 10, 25, 30]);
    expect(conCortes[2]).toEqual({ t: 10, bpm: null, spo2: null, hrv: null });
  });

  test('una serie sin huecos queda igual', () => {
    expect(serieConCortes(serie.slice(0, 2))).toEqual(serie.slice(0, 2));
  });

  test('ubica los tramos sin señal válida', () => {
    expect(huecosDeSerie(serie)).toEqual([{ desde: 10, hasta: 25 }]);
    expect(huecosDeSerie(serie.slice(0, 2))).toEqual([]);
  });
});

describe('formato', () => {
  test('porcentajeCalidad', () => {
    expect(porcentajeCalidad(0.841)).toBe(84);
    expect(porcentajeCalidad(1)).toBe(100);
    expect(porcentajeCalidad(null)).toBeNull();
  });

  test('minSeg y duracionTexto', () => {
    expect(minSeg(0)).toBe('0:00');
    expect(minSeg(125)).toBe('2:05');
    expect(duracionTexto(45)).toBe('45 s');
    expect(duracionTexto(180)).toBe('3 min');
    expect(duracionTexto(214)).toBe('3 min 34 s');
  });

  test('fechaHora en hora local', () => {
    const local = new Date(2026, 9, 13, 9, 5);
    expect(fechaHora(local)).toBe('13 oct 2026, 9:05');
  });
});
