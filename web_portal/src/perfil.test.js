import { filasActividad, INSTITUCION, resumenUrl, textoFechaAlta } from './perfil';

test('fecha de alta en hora de México', () => {
  // 02:00 UTC del 2 de septiembre = 1 de septiembre en México.
  expect(textoFechaAlta('2026-09-02T02:00:00Z')).toBe('1 sep 2026');
  expect(textoFechaAlta(null)).toBe('—');
});

test('actividad: cuatro conteos en orden; lo que falte es 0', () => {
  const filas = filasActividad({ pacientes_vinculados: 4, mensajes_enviados: 17, notas_registradas: 2 });
  expect(filas.map((f) => [f.etiqueta, f.valor])).toEqual([
    ['Pacientes vinculados', 4],
    ['Mensajes enviados', 17],
    ['Notas clínicas registradas', 2],
    ['Reportes exportados este mes', 0],
  ]);
});

test('institución y ruta', () => {
  expect(INSTITUCION).toMatch(/ESCOM/);
  expect(INSTITUCION).toMatch(/Instituto Politécnico Nacional/);
  expect(resumenUrl).toMatch(/\/api\/especialista\/resumen$/);
});
