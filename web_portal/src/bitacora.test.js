import {
  ACCIONES, textoAccion, toneAccion, textoRol, nombreDe, textoDetalle, parametrosConsulta, rangoValido,
} from './bitacora';

const nombres = new Map([['esp-1', 'Dra. Uno'], ['esp-2', 'Dr. Dos']]);
const fila = (accion, detalle = {}) => ({ accion, detalle });

test('las acciones son las mismas del CHECK de la tabla', () => {
  expect(Object.keys(ACCIONES).sort()).toEqual([
    'acceso_datos_clinicos', 'cuenta_eliminada', 'cuenta_reactivada', 'cuenta_suspendida',
    'desvinculacion', 'exportacion', 'marcador_creado', 'marcador_eliminado',
    'nota_creada', 'nota_editada', 'vinculacion',
  ]);
});

test('textos de acción y rol, con respaldo para valores desconocidos', () => {
  expect(textoAccion('exportacion')).toBe('Exportación de reporte');
  expect(textoAccion('otra')).toBe('otra');
  expect(toneAccion('cuenta_eliminada')).toBe('altos');
  expect(toneAccion('otra')).toBe('neutral');
  expect(textoRol('especialista')).toBe('Especialista');
  expect(textoRol(null)).toBe('');
});

test('nombre: el de la fila, luego la lista, luego el uid recortado', () => {
  expect(nombreDe('esp-1', 'Nombre fila', nombres)).toBe('Nombre fila');
  expect(nombreDe('esp-1', null, nombres)).toBe('Dra. Uno');
  expect(nombreDe('abcdefghijkl', null, nombres)).toBe('abcdefgh…');
  expect(nombreDe(null, null, nombres)).toBe('—');
});

test('detalle del acceso y de la exportación', () => {
  expect(textoDetalle(fila('acceso_datos_clinicos', { recurso: 'gad7' }))).toBe('Consultó GAD-7');
  expect(textoDetalle(fila('acceso_datos_clinicos', { recurso: 'x' }))).toBe('');
  expect(textoDetalle(fila('exportacion', { formato: 'csv', seudonimizado: true, desde: '2026-10-01', hasta: '2026-10-31' })))
    .toBe('CSV · seudonimizado · 2026-10-01 a 2026-10-31');
  expect(textoDetalle(fila('exportacion', { formato: 'pdf', seudonimizado: false })))
    .toBe('PDF · con identificación');
});

test('detalle de la vinculación con nombres de la lista', () => {
  expect(textoDetalle(fila('vinculacion', { especialista_anterior: null, especialista_nuevo: 'esp-1', via: 'codigo' }), nombres))
    .toBe('Con Dra. Uno (con código)');
  expect(textoDetalle(fila('vinculacion', { especialista_anterior: 'esp-1', especialista_nuevo: 'esp-2', via: 'admin' }), nombres))
    .toBe('De Dra. Uno a Dr. Dos (por el administrador)');
  expect(textoDetalle(fila('desvinculacion', { especialista_anterior: 'esp-2', via: 'admin' }), nombres))
    .toBe('De Dr. Dos (por el administrador)');
});

test('el detalle nunca muestra claves inesperadas', () => {
  expect(textoDetalle(fila('nota_creada', { nota_id: 'n1', contenido: 'texto clínico' }))).toBe('');
  expect(textoDetalle(fila('marcador_creado', { descripcion: 'algo' }))).toBe('');
  expect(textoDetalle(fila('nota_editada', { version: 3, contenido: 'x' }))).toBe('Versión 3');
  expect(textoDetalle({ accion: 'cuenta_suspendida' })).toBe('');
});

test('parámetros: solo los filtros con valor y el cursor', () => {
  expect(parametrosConsulta({})).toEqual({});
  expect(parametrosConsulta({ desde: '2026-11-01', hasta: '', usuario: 'u1', accion: '' }, 42))
    .toEqual({ desde: '2026-11-01', usuario: 'u1', antes_de: '42' });
});

test('rango de fechas', () => {
  expect(rangoValido({})).toBe(true);
  expect(rangoValido({ desde: '2026-11-01' })).toBe(true);
  expect(rangoValido({ desde: '2026-11-01', hasta: '2026-11-01' })).toBe(true);
  expect(rangoValido({ desde: '2026-11-02', hasta: '2026-11-01' })).toBe(false);
});
