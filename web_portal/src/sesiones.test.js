import {
  normalizarSesion, resumenSesiones, datosTendencia, serieConCortes, huecosDeSerie,
  porcentajeCalidad, minSeg, duracionTexto, fechaHora, ticksEje,
  evaSobre10, textoContextoEva, demoraEva,
  origenesPresentes, origenMasReciente, textoOrigen, dominioConBanda,
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
  test('ticksEje: cada minuto, o cada 2 si la sesión pasa de 5 min', () => {
    expect(ticksEje(214)).toEqual([0, 60, 120, 180]);
    expect(ticksEje(420)).toEqual([0, 120, 240, 360]);
  });

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

describe('EVA (Fase M2)', () => {
  test('evaSobre10: un decimal; omitida → "—"', () => {
    expect(evaSobre10(63)).toBe('6.3');
    expect(evaSobre10(0)).toBe('0.0');
    expect(evaSobre10(100)).toBe('10.0');
    expect(evaSobre10(null)).toBe('—');
    expect(evaSobre10(undefined)).toBe('—');
  });

  test('normalizarSesion convierte eva_valor y deja null si se omitió', () => {
    expect(normalizarSesion(fila('a', '2026-10-13T15:30:00Z', { eva_valor: '63' })).eva_valor).toBe(63);
    expect(normalizarSesion(fila('a', '2026-10-13T15:30:00Z', { eva_valor: null })).eva_valor).toBeNull();
  });

  test('textoContextoEva: los textos de la app; null → "Sin contexto"', () => {
    expect(textoContextoEva('reposo')).toBe('En reposo');
    expect(textoContextoEva('antes_examen')).toBe('Antes de un examen');
    expect(textoContextoEva('despues_estresor')).toBe('Después de una situación estresante');
    expect(textoContextoEva(null)).toBe('Sin contexto');
  });

  test('demoraEva: desde el fin de la medición (inicio + duración)', () => {
    // Inicio 15:30:00, 214 s → fin 15:33:34.
    const s = (evaFecha) => ({ fecha_inicio: '2026-10-13T15:30:00Z', duracion_total_seg: 214, eva_fecha: evaFecha });
    expect(demoraEva(s('2026-10-13T15:34:00Z'))).toBe('Respondida al terminar');
    expect(demoraEva(s('2026-10-13T15:34:40Z'))).toBe('Respondida 1 min después');
    expect(demoraEva(s('2026-10-13T15:45:00Z'))).toBe('Respondida 11 min después');
    // Desfase de relojes: la respuesta "antes" del fin cuenta como 0.
    expect(demoraEva(s('2026-10-13T15:32:00Z'))).toBe('Respondida al terminar');
    expect(demoraEva(s(null))).toBeNull();
  });
});

// Fase M3: la evaluación contra la línea base que manda el backend al
// especialista (ya es número: se calcula en JS, no sale de un numeric).
describe('línea base en la tendencia (M3)', () => {
  const ahora = new Date('2026-10-16T18:00:00Z').getTime();
  const banda = (min, max) => ({ n: 5, rango_hrv_ms: { min, max } });
  const sesiones = [
    fila('sim1', '2026-10-10T14:00:00Z', {
      evaluacion: { estado: null, etapa: 'calibrando', motivo_sin_estado: 'calibrando', banda: null },
    }),
    fila('sen1', '2026-10-12T14:00:00Z', {
      origen: 'sensor', hrv_rmssd: '61',
      evaluacion: { estado: null, etapa: 'calibrando', motivo_sin_estado: 'calibrando', banda: null },
    }),
    fila('sim2', '2026-10-14T14:00:00Z', {
      hrv_rmssd: '33.5',
      evaluacion: { estado: 'altos', etapa: 'consolidada', motivo_sin_estado: null, banda: banda(41.8, 51) },
    }),
    // Sesión sin evaluación (backend sin el paso 2): no rompe la gráfica.
    fila('vieja', '2026-10-15T14:00:00Z'),
  ].map(normalizarSesion);

  test('cada punto lleva su banda, estado y etapa; null mientras se calibra', () => {
    const datos = datosTendencia(sesiones, { ahora, origen: 'simulacion' });
    expect(datos.map((d) => d.hrv)).toEqual([42.46, 33.5, 42.46]);
    expect(datos[0]).toMatchObject({ banda: null, estado: null, etapa: 'calibrando', motivo_sin_estado: 'calibrando' });
    expect(datos[1]).toMatchObject({ banda: [41.8, 51], estado: 'altos', etapa: 'consolidada' });
    expect(datos[2]).toMatchObject({ banda: null, estado: null, etapa: null });
  });

  test('filtra por origen; sin origen trae todas', () => {
    expect(datosTendencia(sesiones, { ahora, origen: 'sensor' }).map((d) => d.hrv)).toEqual([61]);
    expect(datosTendencia(sesiones, { ahora })).toHaveLength(4);
  });

  test('orígenes presentes y el de la sesión más reciente', () => {
    expect(origenesPresentes(sesiones)).toEqual(['simulacion', 'sensor']);
    expect(origenesPresentes(sesiones.filter((s) => s.origen === 'sensor'))).toEqual(['sensor']);
    expect(origenMasReciente(sesiones)).toBe('simulacion');
    expect(origenMasReciente([])).toBeNull();
    expect(textoOrigen('sensor')).toBe('Sensor');
  });

  test('dominioConBanda: el eje cubre los datos y la franja completa', () => {
    expect(dominioConBanda([40, 45, null], { min: 41.8, max: 51 })).toEqual([35, 56]);
    expect(dominioConBanda([40, 45], null)).toEqual([35, 50]);
    expect(dominioConBanda([2], null)).toEqual([0, 7]);
  });
});
