// Pruebas de bitacora.js (Bloque 2, paso 1). Correr con `npm test`.
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  ACCIONES, RECURSOS, DETALLE_PERMITIDO, parametrosBitacora, registrar, DedupeAccesos,
  validarFiltrosBitacora, consultaBitacora, paginaBitacora,
} = require('./bitacora');
const { ValidationError } = require('./errors');

const entrada = (extra = {}) => ({
  actorId: 'uid-esp', actorRol: 'especialista', accion: 'acceso_datos_clinicos',
  objetivoId: 'uid-pac', detalle: { recurso: 'sesiones' }, ...extra,
});

// --- Registro ---

test('las acciones coinciden con el CHECK del DDL del Bloque 2', () => {
  assert.deepEqual([...ACCIONES].sort(), [
    'acceso_datos_clinicos', 'cuenta_eliminada', 'cuenta_reactivada', 'cuenta_suspendida',
    'desvinculacion', 'exportacion', 'marcador_creado', 'marcador_eliminado',
    'nota_creada', 'nota_editada', 'vinculacion',
  ]);
});

test('ninguna acción admite claves de contenido clínico', () => {
  const prohibidas = ['contenido', 'descripcion', 'texto', 'valor', 'puntaje', 'severidad', 'tipo', 'contexto', 'nombre', 'email'];
  for (const [accion, claves] of Object.entries(DETALLE_PERMITIDO)) {
    for (const clave of claves) assert.ok(!prohibidas.includes(clave), `${accion}.${clave}`);
  }
});

test('arma los parámetros del INSERT con el detalle en JSON', () => {
  assert.deepEqual(parametrosBitacora(entrada()), [
    'uid-esp', 'especialista', 'acceso_datos_clinicos', 'uid-pac', '{"recurso":"sesiones"}',
  ]);
});

test('sin objetivo ni detalle: null y objeto vacío', () => {
  const p = parametrosBitacora({ actorId: 'a', actorRol: 'admin', accion: 'cuenta_reactivada' });
  assert.equal(p[3], null);
  assert.equal(p[4], '{}');
});

test('rechaza una acción desconocida', () => {
  assert.throws(() => parametrosBitacora(entrada({ accion: 'nota_borrada' })), /acción desconocida/);
});

test('rechaza una clave de detalle fuera de la lista', () => {
  assert.throws(
    () => parametrosBitacora(entrada({ accion: 'nota_editada', detalle: { nota_id: 'n1', contenido: 'x' } })),
    /'contenido' no está permitida/
  );
});

test('rechaza valores que no son simples o son largos', () => {
  assert.throws(() => parametrosBitacora(entrada({ accion: 'nota_creada', detalle: { nota_id: { a: 1 } } })), /valor no permitido/);
  assert.throws(() => parametrosBitacora(entrada({ accion: 'nota_creada', detalle: { nota_id: 'x'.repeat(65) } })), /valor no permitido/);
  assert.throws(() => parametrosBitacora(entrada({ accion: 'nota_editada', detalle: { version: NaN } })), /valor no permitido/);
});

test('acepta booleanos, números y null', () => {
  const p = parametrosBitacora(entrada({
    accion: 'exportacion', detalle: { formato: 'csv', seudonimizado: true, desde: '2026-10-01', hasta: null },
  }));
  assert.equal(p[4], '{"formato":"csv","seudonimizado":true,"desde":"2026-10-01","hasta":null}');
});

test('el acceso exige un recurso conocido', () => {
  for (const recurso of RECURSOS) assert.ok(parametrosBitacora(entrada({ detalle: { recurso } })));
  assert.throws(() => parametrosBitacora(entrada({ detalle: { recurso: 'otra' } })), /recurso desconocido/);
  assert.throws(() => parametrosBitacora(entrada({ detalle: {} })), /recurso desconocido/);
});

test('exige el actor', () => {
  assert.throws(() => parametrosBitacora(entrada({ actorId: null })), /falta el actor/);
  assert.throws(() => parametrosBitacora(entrada({ actorRol: '' })), /falta el actor/);
});

test('registrar hace un solo INSERT en el db que recibe', async () => {
  const llamadas = [];
  await registrar({ query: async (sql, params) => llamadas.push({ sql, params }) }, entrada());
  assert.equal(llamadas.length, 1);
  assert.match(llamadas[0].sql, /INSERT INTO bitacora/);
  assert.equal(llamadas[0].params[2], 'acceso_datos_clinicos');
});

test('registrar no toca la base si la entrada es inválida', async () => {
  let llamadas = 0;
  await assert.rejects(registrar({ query: async () => { llamadas++; } }, entrada({ accion: 'x' })));
  assert.equal(llamadas, 0);
});

// --- Dedupe de accesos ---

test('un acceso por par dentro de la ventana', () => {
  let t = 0;
  const d = new DedupeAccesos({ ventanaMs: 1000, ahora: () => t });
  assert.equal(d.reservar('e', 'p'), true);
  t = 999;
  assert.equal(d.reservar('e', 'p'), false);
  t = 1000;
  assert.equal(d.reservar('e', 'p'), true);
});

test('pares distintos no se estorban', () => {
  const d = new DedupeAccesos({ ahora: () => 0 });
  assert.equal(d.reservar('e1', 'p'), true);
  assert.equal(d.reservar('e2', 'p'), true);
  assert.equal(d.reservar('e1', 'p2'), true);
  assert.equal(d.reservar('e1', 'p'), false);
});

test('liberar permite reintentar enseguida (el INSERT falló)', () => {
  const d = new DedupeAccesos({ ahora: () => 0 });
  d.reservar('e', 'p');
  d.liberar('e', 'p');
  assert.equal(d.reservar('e', 'p'), true);
});

test('al llenarse purga lo vencido y nunca crece sin límite', () => {
  let t = 0;
  const d = new DedupeAccesos({ ventanaMs: 10, maximo: 3, ahora: () => t });
  d.reservar('e', 'p1');
  d.reservar('e', 'p2');
  t = 20;
  d.reservar('e', 'p3');
  d.reservar('e', 'p4'); // purga p1 y p2
  assert.ok(d.ultimos.size <= 3);
  for (let i = 0; i < 20; i++) d.reservar('e', `q${i}`);
  assert.ok(d.ultimos.size <= 3);
});

// --- Filtros y consulta del admin ---

test('sin filtros: límite por defecto y sin WHERE', () => {
  const f = validarFiltrosBitacora({});
  assert.deepEqual(f, { desde: null, hasta: null, usuario: null, accion: null, antes_de: null, limite: 100 });
  const { sql, params } = consultaBitacora(f);
  assert.doesNotMatch(sql, /WHERE/);
  assert.equal(params[params.length - 1], 101);
});

test('todos los filtros van como parámetros, nunca en el SQL', () => {
  const f = validarFiltrosBitacora({
    desde: '2026-11-01', hasta: '2026-11-04', usuario: 'abcDEF123_-', accion: 'exportacion', antes_de: '500', limite: '20',
  });
  const { sql, params } = consultaBitacora(f);
  assert.deepEqual(params, ['America/Mexico_City', '2026-11-01', '2026-11-04', 'abcDEF123_-', 'exportacion', 500, 21]);
  for (const v of ['2026-11-01', 'abcDEF123_-', 'exportacion']) assert.ok(!sql.includes(v));
  assert.match(sql, /b\.actor_id = \$4 OR b\.objetivo_id = \$4/);
  assert.match(sql, /::date \+ 1\)::timestamp AT TIME ZONE \$1/);
  assert.match(sql, /b\.id < \$6/);
});

// Postgres rechaza un parámetro que el SQL no usa ("could not determine data
// type of parameter $1"): con `usuario` solo, o sin filtros, la zona horaria
// iba como $1 sin aparecer en la consulta y la ruta respondía 500.
test('cada parámetro aparece en el SQL ($1..$n, sin huecos), con cualquier combinación de filtros', () => {
  const valores = {
    desde: '2026-11-01', hasta: '2026-11-04', usuario: 'abc123', accion: 'exportacion', antes_de: '500', limite: '20',
  };
  const campos = Object.keys(valores);
  for (let mascara = 0; mascara < 2 ** campos.length; mascara++) {
    const query = {};
    campos.forEach((c, i) => { if (mascara & (1 << i)) query[c] = valores[c]; });
    const { sql, params } = consultaBitacora(validarFiltrosBitacora(query));
    const usados = new Set([...sql.matchAll(/\$(\d+)/g)].map((m) => Number(m[1])));
    for (let n = 1; n <= params.length; n++) {
      assert.ok(usados.has(n), `$${n} no aparece en el SQL con ${JSON.stringify(query)}`);
    }
    assert.equal(Math.max(...usados), params.length, JSON.stringify(query));
    assert.equal(params.includes('America/Mexico_City'), Boolean(query.desde || query.hasta), JSON.stringify(query));
  }
});

test('la consulta no trae columnas de tablas clínicas', () => {
  const { sql } = consultaBitacora(validarFiltrosBitacora({}));
  assert.doesNotMatch(sql, /notas_clinicas|marcadores|sesiones|gad7|mensajes/);
});

test('rechaza filtros inválidos con 400', () => {
  const casos = [
    { desde: '2026-13-01' }, { hasta: '2026-02-30' }, { desde: '04/11/2026' },
    { desde: '2026-11-05', hasta: '2026-11-04' },
    { usuario: "x' OR 1=1" }, { usuario: 'a'.repeat(51) },
    { accion: 'borrar_todo' }, { antes_de: '0' }, { antes_de: '-1' }, { antes_de: '1.5' },
    { limite: '0' }, { limite: '201' }, { limite: 'diez' },
    { otro: '1' }, { accion: ['exportacion', 'vinculacion'] },
  ];
  for (const q of casos) {
    assert.throws(() => validarFiltrosBitacora(q), (e) => e instanceof ValidationError, JSON.stringify(q));
  }
});

test('los textos vacíos cuentan como sin filtro', () => {
  const f = validarFiltrosBitacora({ desde: '', usuario: '  ', accion: '' });
  assert.equal(f.desde, null);
  assert.equal(f.usuario, null);
  assert.equal(f.accion, null);
});

test('paginación: con la fila de más hay cursor; sin ella, no', () => {
  const filas = [{ id: '30' }, { id: '20' }, { id: '10' }];
  assert.deepEqual(paginaBitacora(filas, 2), { filas: filas.slice(0, 2), siguiente: 20 });
  assert.deepEqual(paginaBitacora(filas, 3), { filas, siguiente: null });
  assert.deepEqual(paginaBitacora([], 3), { filas: [], siguiente: null });
});
