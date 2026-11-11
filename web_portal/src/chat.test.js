import {
  etiquetaDia, horaLocal, conSeparadores, fechaBandeja, estadoConversacion, contarPendientes,
  teclaEnvia, altoCaja, conversacionesUrl, LINEAS_MAXIMAS, TEXTO_MAXIMO,
} from './chat';

// "Ahora" fijo: martes 10 de noviembre de 2026, 12:00 en México (18:00 UTC).
const AHORA = new Date('2026-11-10T18:00:00Z');

describe('etiquetaDia', () => {
  test('hoy, ayer y otro día del año', () => {
    expect(etiquetaDia('2026-11-10T15:00:00Z', AHORA)).toBe('Hoy');
    expect(etiquetaDia('2026-11-09T15:00:00Z', AHORA)).toBe('Ayer');
    expect(etiquetaDia('2026-11-02T15:00:00Z', AHORA)).toBe('lunes 2 de noviembre');
  });

  test('otro año lleva el año', () => {
    expect(etiquetaDia('2025-12-31T18:00:00Z', AHORA)).toBe('miércoles 31 de diciembre de 2025');
  });

  test('usa la hora de México, no UTC: las 01:00 UTC del 10 son el 9 en México', () => {
    expect(etiquetaDia('2026-11-10T01:00:00Z', AHORA)).toBe('Ayer');
    expect(etiquetaDia('2026-11-10T06:30:00Z', AHORA)).toBe('Hoy');
  });
});

test('horaLocal: 24 h en hora de México', () => {
  expect(horaLocal('2026-11-10T20:05:00Z')).toBe('14:05');
  expect(horaLocal('2026-11-10T06:00:00Z')).toBe('00:00');
  expect(horaLocal(null)).toBe('');
});

test('conSeparadores: un separador cada vez que cambia el día', () => {
  const items = conSeparadores([
    { id: 'a', fecha_envio: '2026-11-09T15:00:00Z' },
    { id: 'b', fecha_envio: '2026-11-09T23:00:00Z' },
    { id: 'c', fecha_envio: '2026-11-10T07:00:00Z' },
  ], AHORA);
  expect(items.map((i) => (i.tipo === 'dia' ? `[${i.etiqueta}]` : i.mensaje.id))).toEqual(['[Ayer]', 'a', 'b', '[Hoy]', 'c']);
  expect(new Set(items.map((i) => i.clave)).size).toBe(items.length);
  expect(conSeparadores([], AHORA)).toEqual([]);
});

test('fechaBandeja: hora, "Ayer" o fecha corta', () => {
  expect(fechaBandeja('2026-11-10T16:30:00Z', AHORA)).toBe('10:30');
  expect(fechaBandeja('2026-11-09T16:30:00Z', AHORA)).toBe('Ayer');
  expect(fechaBandeja('2026-11-02T16:30:00Z', AHORA)).toBe('2 nov');
  expect(fechaBandeja('2025-11-02T16:30:00Z', AHORA)).toBe('2 nov 2025');
  expect(fechaBandeja(null, AHORA)).toBe('');
});

test('estadoConversacion y contarPendientes', () => {
  expect(estadoConversacion({ pendiente: true, sin_responder: 1 })).toBe('Pendiente de responder');
  expect(estadoConversacion({ pendiente: true, sin_responder: 3 })).toBe('Pendiente de responder · 3 mensajes');
  expect(estadoConversacion({ pendiente: false, ultimo_de: 'especialista' })).toBe('Respondida');
  expect(estadoConversacion({ pendiente: false, ultimo_de: null })).toBe('Sin mensajes todavía');
  expect(contarPendientes([{ pendiente: true }, { pendiente: false }, { pendiente: true }])).toBe(2);
  expect(contarPendientes(null)).toBe(0);
});

describe('teclaEnvia', () => {
  test('Enter envía; Shift+Enter no', () => {
    expect(teclaEnvia({ key: 'Enter' })).toBe(true);
    expect(teclaEnvia({ key: 'Enter', shiftKey: true })).toBe(false);
    expect(teclaEnvia({ key: 'a' })).toBe(false);
  });

  test('no envía mientras se compone un carácter', () => {
    expect(teclaEnvia({ key: 'Enter', nativeEvent: { isComposing: true } })).toBe(false);
    expect(teclaEnvia({ key: 'Enter', keyCode: 229 })).toBe(false);
  });
});

test('altoCaja: de 1 a 5 líneas y luego scroll', () => {
  const base = { altoLinea: 20, relleno: 22 };
  expect(altoCaja({ ...base, scrollHeight: 10 })).toEqual({ alto: 42, conScroll: false });
  expect(altoCaja({ ...base, scrollHeight: 82 })).toEqual({ alto: 82, conScroll: false });
  expect(altoCaja({ ...base, scrollHeight: 20 * LINEAS_MAXIMAS + 22 })).toEqual({ alto: 122, conScroll: false });
  expect(altoCaja({ ...base, scrollHeight: 400 })).toEqual({ alto: 122, conScroll: true });
});

test('ruta de la bandeja y límite del texto', () => {
  expect(conversacionesUrl).toMatch(/\/api\/especialista\/conversaciones$/);
  expect(TEXTO_MAXIMO).toBe(2000);
});
