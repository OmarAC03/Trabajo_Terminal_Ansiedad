import {
  resumenActividad, ordenarPorActividad, actividadReciente, grupoRecencia, conteoRecencia,
  coincideFiltroActividad, conteoEstado,
} from './actividad';

// "Ahora" fijo en hora local: 14 oct 2026, 12:00.
const AHORA = new Date(2026, 9, 14, 12, 0).getTime();
const haceHoras = (h) => new Date(AHORA - h * 60 * 60 * 1000).toISOString();

// Filas como las manda GET /api/pacientes. "Viejo" solo tiene lecturas del
// método previo y ninguna sesión: su fila no debe romper nada.
const pacientes = [
  { id: '1', nombre: 'Beatriz', ultima_sesion: haceHoras(2), ultima_sesion_origen: 'simulacion', sesiones_7d: 3 },
  { id: '2', nombre: 'Ana', ultima_sesion: haceHoras(48), ultima_sesion_origen: 'sensor', sesiones_7d: 1 },
  { id: '3', nombre: 'Carlos', ultima_sesion: haceHoras(24 * 10), ultima_sesion_origen: 'sensor', sesiones_7d: 0 },
  {
    id: '4', nombre: 'Viejo', ultima_sesion: null, ultima_sesion_origen: null, sesiones_7d: 0,
    ultimo_estado: 'Alta', ultima_lectura: '2026-10-06T10:00:00Z',
  },
  { id: '5', nombre: 'Diana', ultima_sesion: null, ultima_sesion_origen: null, sesiones_7d: 0 },
];

describe('resumenActividad', () => {
  test('cuenta actividad de 7 días, sin clasificar a nadie', () => {
    expect(resumenActividad(pacientes)).toEqual({
      total: 5, conSesiones: 3, midieron: 2, sinMedir: 3, sesiones: 4,
    });
  });

  test('lista vacía y sesiones_7d ausente (backend viejo) no rompen', () => {
    expect(resumenActividad([])).toEqual({ total: 0, conSesiones: 0, midieron: 0, sinMedir: 0, sesiones: 0 });
    expect(resumenActividad([{ nombre: 'X' }]).sesiones).toBe(0);
  });
});

describe('orden y actividad reciente', () => {
  test('la sesión más reciente primero; quien nunca midió al final, por nombre', () => {
    expect(ordenarPorActividad(pacientes).map((p) => p.nombre)).toEqual(['Beatriz', 'Ana', 'Carlos', 'Diana', 'Viejo']);
  });

  test('no modifica la lista original', () => {
    const copia = [...pacientes];
    ordenarPorActividad(pacientes);
    expect(pacientes).toEqual(copia);
  });

  test('actividad reciente: solo quien tiene sesiones, con tope', () => {
    expect(actividadReciente(pacientes).map((p) => p.nombre)).toEqual(['Beatriz', 'Ana', 'Carlos']);
    expect(actividadReciente(pacientes, 1).map((p) => p.nombre)).toEqual(['Beatriz']);
  });
});

describe('grupos por recencia', () => {
  test('hoy / últimos 7 días / más de 7 días / sin sesiones', () => {
    expect(pacientes.map((p) => grupoRecencia(p, AHORA))).toEqual(['hoy', 'semana', 'antes', 'nunca', 'nunca']);
  });

  test('"hoy" es el día calendario local, no las últimas 24 h', () => {
    const anoche = new Date(2026, 9, 13, 23, 30).toISOString(); // hace 12.5 h, pero fue ayer
    expect(grupoRecencia({ ultima_sesion: anoche }, AHORA)).toBe('semana');
  });

  test('conteo: cada paciente cuenta una vez', () => {
    expect(conteoRecencia(pacientes, AHORA).map((g) => [g.clave, g.valor])).toEqual([
      ['hoy', 1], ['semana', 1], ['antes', 1], ['nunca', 2],
    ]);
  });
});

describe('filtro de actividad', () => {
  test('midieron / sin medir en 7 días / todos', () => {
    const nombres = (f) => pacientes.filter((p) => coincideFiltroActividad(p, f)).map((p) => p.nombre);
    expect(nombres('midieron')).toEqual(['Beatriz', 'Ana']);
    expect(nombres('sin-medir')).toEqual(['Carlos', 'Viejo', 'Diana']);
    expect(nombres(null)).toHaveLength(5);
  });
});

describe('estado de la última sesión (M3)', () => {
  test('cuenta por estado; sin estado junta calibrando, calidad baja y nunca midió', () => {
    const conEstado = [
      { id: 'a', ultima_sesion: haceHoras(1), ultima_sesion_estado: 'altos' },
      { id: 'b', ultima_sesion: haceHoras(2), ultima_sesion_estado: 'normal' },
      { id: 'c', ultima_sesion: haceHoras(3), ultima_sesion_estado: 'normal' },
      { id: 'd', ultima_sesion: haceHoras(4), ultima_sesion_estado: null, ultima_sesion_motivo_sin_estado: 'calibrando' },
      { id: 'e', ultima_sesion: haceHoras(5), ultima_sesion_estado: null, ultima_sesion_motivo_sin_estado: 'calidad_baja' },
      { id: 'f', ultima_sesion: null, ultima_sesion_estado: null },
      // Fila sin los campos de M3 (backend sin el paso 2): cuenta como sin estado.
      { id: 'g', ultima_sesion: haceHoras(6) },
    ];
    expect(conteoEstado(conEstado).map((g) => [g.clave, g.valor])).toEqual([
      ['normal', 2], ['elevados', 0], ['altos', 1], ['sin-datos', 4],
    ]);
  });
});
