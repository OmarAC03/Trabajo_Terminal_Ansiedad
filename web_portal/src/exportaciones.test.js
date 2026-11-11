import { exportacionesUrl, fechaHora, filaHistorial, pacientesParaExportar, SIN_VINCULO } from './exportaciones';

test('fechaHora en hora de México', () => {
  expect(fechaHora('2026-11-10T20:05:00Z')).toBe('10 nov 2026, 14:05');
});

test('fila de un paciente vinculado', () => {
  expect(filaHistorial({
    id: '7', fecha: '2026-11-10T20:05:00Z', vinculado: true, paciente_nombre: 'Ana',
    formato: 'csv', seudonimizado: true, desde: '2026-10-12', hasta: '2026-11-10',
  })).toEqual({
    clave: '7', fecha: '10 nov 2026, 14:05', paciente: 'Ana', vinculado: true, formato: 'CSV',
    identificacion: 'Seudonimizado', periodo: '12 oct 2026 – 10 nov 2026',
  });
});

test('un paciente ya no vinculado no muestra nombre', () => {
  const f = filaHistorial({ id: '8', fecha: '2026-11-10T20:05:00Z', vinculado: false, paciente_nombre: null, formato: 'pdf', seudonimizado: false });
  expect(f.paciente).toBe(SIN_VINCULO);
  expect(f.formato).toBe('PDF');
  expect(f.identificacion).toBe('Con nombre');
  expect(f.periodo).toBe('—');
});

test('pacientes por nombre sin tocar la lista original', () => {
  const lista = [{ nombre: 'Zoe' }, { nombre: 'Ángel' }, { nombre: 'Beto' }];
  expect(pacientesParaExportar(lista).map((p) => p.nombre)).toEqual(['Ángel', 'Beto', 'Zoe']);
  expect(lista[0].nombre).toBe('Zoe');
  expect(pacientesParaExportar(null)).toEqual([]);
});

test('ruta del historial', () => {
  expect(exportacionesUrl).toMatch(/\/api\/especialista\/exportaciones$/);
});
