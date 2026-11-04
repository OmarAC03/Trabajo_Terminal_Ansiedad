import {
  TIPOS_MARCADOR, textoTipo, marcadoresEnGrafica, dominioTiempo, ticksDias, valorLocal, isoDesdeLocal, errorMarcador,
  marcadoresUrl,
} from './marcadores';

const DIA = 24 * 60 * 60 * 1000;

test('tipos: los mismos del CHECK de la tabla (D4)', () => {
  expect(TIPOS_MARCADOR.map((t) => t.id)).toEqual(['consulta', 'periodo_examenes', 'evento_personal', 'intervencion', 'otro']);
  expect(textoTipo('periodo_examenes')).toBe('Periodo de exámenes');
  expect(textoTipo('raro')).toBe('raro');
  expect(marcadoresUrl('p1')).toMatch(/\/api\/pacientes\/p1\/marcadores$/);
});

test('en la gráfica: solo los últimos 30 días, ordenados y numerados', () => {
  const ahora = new Date('2026-11-04T18:00:00Z').getTime();
  const lista = [
    { id: 'b', fecha: '2026-11-02T16:00:00Z', tipo: 'consulta' },
    { id: 'viejo', fecha: '2026-09-01T16:00:00Z', tipo: 'otro' },
    { id: 'a', fecha: '2026-10-20T16:00:00Z', tipo: 'periodo_examenes' },
  ];
  const r = marcadoresEnGrafica(lista, { ahora });
  expect(r.map((m) => [m.id, m.numero])).toEqual([['a', 1], ['b', 2]]);
  expect(r[0].t).toBe(new Date('2026-10-20T16:00:00Z').getTime());
});

test('dominio del eje: abarca sesiones y marcadores con margen', () => {
  const t0 = new Date('2026-10-01T12:00:00Z').getTime();
  const [a, b] = dominioTiempo([{ t: t0 }, { t: t0 + 10 * DIA }], [{ t: t0 + 20 * DIA }]);
  expect(a).toBeLessThan(t0);
  expect(b).toBeGreaterThan(t0 + 20 * DIA);
  expect(dominioTiempo([{ t: t0 }])).toEqual([t0 - DIA / 2, t0 + DIA / 2]);
  expect(dominioTiempo([])).toEqual(['auto', 'auto']);
});

test('marcas del eje: a medianoche local, sin pasar del máximo', () => {
  const desde = new Date(2026, 9, 1, 15).getTime();
  const ticks = ticksDias([desde, desde + 29 * DIA], 8);
  expect(ticks.length).toBeLessThanOrEqual(8);
  expect(ticks.length).toBeGreaterThan(3);
  for (const t of ticks) {
    expect(new Date(t).getHours()).toBe(0);
    expect(t).toBeGreaterThanOrEqual(desde);
  }
  expect(ticksDias(['auto', 'auto'])).toBeUndefined();
});

test('datetime-local ida y vuelta', () => {
  const d = new Date(2026, 10, 4, 9, 5);
  expect(valorLocal(d)).toBe('2026-11-04T09:05');
  expect(isoDesdeLocal('2026-11-04T09:05')).toBe(d.toISOString());
  expect(isoDesdeLocal('2026-11-04')).toBeNull();
});

test('validación del formulario', () => {
  const ahora = new Date(2026, 10, 4, 12, 0).getTime();
  const ok = { tipo: 'consulta', fecha: '2026-11-04T10:00', descripcion: '' };
  expect(errorMarcador(ok, ahora)).toBe('');
  expect(errorMarcador({ ...ok, tipo: '' }, ahora)).toMatch(/tipo/);
  expect(errorMarcador({ ...ok, fecha: '' }, ahora)).toMatch(/fecha/);
  expect(errorMarcador({ ...ok, fecha: '2026-11-04T13:00' }, ahora)).toMatch(/posterior/);
  expect(errorMarcador({ ...ok, descripcion: 'x'.repeat(141) }, ahora)).toMatch(/140/);
});
