import { diaLocal, textoDia, largo, errorBorrador, hayCambios, textoVersion, mensajeError, notasUrl, CONTENIDO_MAXIMO } from './notas';

test('día local de Ciudad de México, no UTC', () => {
  expect(diaLocal('2026-11-05T05:30:00Z')).toBe('2026-11-04');
  expect(diaLocal('2026-11-05T06:30:00Z')).toBe('2026-11-05');
});

test('texto del día sin corrimiento por zona horaria', () => {
  expect(textoDia('2026-11-04')).toBe('4 nov 2026');
  expect(textoDia('2026-01-31')).toBe('31 ene 2026');
  expect(textoDia('raro')).toBe('raro');
  expect(textoDia(null)).toBe('');
});

test('largo en caracteres reales', () => {
  expect(largo('🙂🙂')).toBe(2);
  expect(largo(null)).toBe(0);
});

test('borrador: fecha, no futura, con texto y dentro del máximo', () => {
  const hoy = '2026-11-04';
  expect(errorBorrador({ fecha: '', contenido: 'x' }, hoy)).toMatch(/fecha/);
  expect(errorBorrador({ fecha: '2026-11-05', contenido: 'x' }, hoy)).toMatch(/posterior/);
  expect(errorBorrador({ fecha: hoy, contenido: '   ' }, hoy)).toMatch(/contenido/);
  expect(errorBorrador({ fecha: hoy, contenido: 'x'.repeat(CONTENIDO_MAXIMO + 1) }, hoy)).toMatch(/5000/);
  expect(errorBorrador({ fecha: hoy, contenido: 'Bien' }, hoy)).toBe('');
});

test('cambios: compara con el texto recortado', () => {
  const nota = { fecha: '2026-11-04', contenido: 'A' };
  expect(hayCambios(nota, { fecha: '2026-11-04', contenido: ' A ' })).toBe(false);
  expect(hayCambios(nota, { fecha: '2026-11-03', contenido: 'A' })).toBe(true);
  expect(hayCambios(nota, { fecha: '2026-11-04', contenido: 'B' })).toBe(true);
});

test('línea de versión', () => {
  const f = (x) => `[${x}]`;
  expect(textoVersion({ version: 1, creada_en: 'c', editada_en: null }, f)).toBe('Escrita el [c]');
  expect(textoVersion({ version: 3, creada_en: 'c', editada_en: 'e' }, f)).toBe('Versión 3 · editada el [e]');
});

test('mensajes de error y URL', () => {
  expect(mensajeError({ response: { status: 409, data: { error: 'Cambió' } } }, 'x')).toBe('Cambió');
  expect(mensajeError({ response: { status: 403 } }, 'x')).toMatch(/no está vinculado/);
  expect(mensajeError({}, 'Por defecto')).toBe('Por defecto');
  expect(notasUrl('p1')).toMatch(/\/api\/pacientes\/p1\/notas$/);
});
