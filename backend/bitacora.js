const { ValidationError } = require('./errors');

// Bitácora (Bloque 2, paso 1: WEB-RF-31 / RNF-WEB-05). Lógica pura, sin base:
// server.js y admin.js registran con `registrar(db, entrada)` y
// bitacora.test.js la prueba.
//
// La tabla `bitacora` es de solo inserción (triggers en la base) y guarda
// QUIÉN, QUÉ ACCIÓN, SOBRE QUIÉN y CUÁNDO. Nunca contenido clínico: `detalle`
// solo admite las claves de DETALLE_PERMITIDO para cada acción, con valores
// simples (texto corto, número o booleano). Una clave fuera de la lista es un
// error de programación (500), no un dato del cliente.

const DETALLE_PERMITIDO = Object.freeze({
  acceso_datos_clinicos: ['recurso'],
  exportacion: ['formato', 'seudonimizado', 'desde', 'hasta'],
  nota_creada: ['nota_id'],
  nota_editada: ['nota_id', 'version'],
  marcador_creado: ['marcador_id'],
  marcador_eliminado: ['marcador_id'],
  vinculacion: ['especialista_anterior', 'especialista_nuevo', 'via'],
  desvinculacion: ['especialista_anterior', 'via'],
  cuenta_suspendida: [],
  cuenta_reactivada: [],
  cuenta_eliminada: ['solicitud_id'],
});
const ACCIONES = Object.freeze(Object.keys(DETALLE_PERMITIDO));

// Qué datos clínicos consultó el especialista (detalle.recurso del acceso).
const RECURSOS = Object.freeze([
  'lecturas', 'sesiones', 'linea_base', 'gad7', 'mensajes', 'ejercicios', 'notas', 'marcadores',
]);

const LARGO_MAXIMO_VALOR = 64;

const INSERTAR = `
  INSERT INTO bitacora (actor_id, actor_rol, accion, objetivo_id, detalle)
  VALUES ($1, $2, $3, $4, $5::jsonb)`;

function valorPermitido(valor) {
  if (valor === null || typeof valor === 'boolean') return true;
  if (typeof valor === 'number') return Number.isFinite(valor);
  return typeof valor === 'string' && valor.length <= LARGO_MAXIMO_VALOR;
}

/**
 * Parámetros del INSERT, ya revisados. Lanza Error (500) si la acción no
 * existe, falta el actor, o `detalle` trae una clave o un valor no permitido.
 */
function parametrosBitacora({ actorId, actorRol, accion, objetivoId = null, detalle = {} }) {
  const permitidas = DETALLE_PERMITIDO[accion];
  if (!permitidas) throw new Error(`Bitácora: acción desconocida '${accion}'.`);
  if (!actorId || !actorRol) throw new Error('Bitácora: falta el actor.');
  for (const [clave, valor] of Object.entries(detalle)) {
    if (!permitidas.includes(clave)) {
      throw new Error(`Bitácora: la clave '${clave}' no está permitida en '${accion}'.`);
    }
    if (!valorPermitido(valor)) {
      throw new Error(`Bitácora: valor no permitido en '${accion}.${clave}'.`);
    }
  }
  if (accion === 'acceso_datos_clinicos' && !RECURSOS.includes(detalle.recurso)) {
    throw new Error(`Bitácora: recurso desconocido '${detalle.recurso}'.`);
  }
  return [actorId, actorRol, accion, objetivoId, JSON.stringify(detalle)];
}

/** Inserta una entrada. `db` es el pool o el cliente de una transacción. */
async function registrar(db, entrada) {
  await db.query(INSERTAR, parametrosBitacora(entrada));
}

// Accesos de lectura (D2): un especialista que abre a un paciente dispara unas
// 6 lecturas, y al pulsar "Actualizar" otras tantas. Se registra UNO por par
// especialista–paciente cada `ventanaMs`. Vive en memoria: si el servidor se
// reinicia, a lo más sale un registro de más.
class DedupeAccesos {
  constructor({ ventanaMs = 10 * 60 * 1000, ahora = () => Date.now(), maximo = 5000 } = {}) {
    this.ventanaMs = ventanaMs;
    this.ahora = ahora;
    this.maximo = maximo;
    this.ultimos = new Map();
  }

  /** true si toca registrar este acceso (y lo aparta para la ventana). */
  reservar(actorId, pacienteId) {
    const clave = `${actorId}|${pacienteId}`;
    const t = this.ahora();
    const ultimo = this.ultimos.get(clave);
    if (ultimo !== undefined && t - ultimo < this.ventanaMs) return false;
    if (this.ultimos.size >= this.maximo) this.purgar(t);
    this.ultimos.set(clave, t);
    return true;
  }

  /** Si el INSERT falló, se libera para reintentar en el siguiente acceso. */
  liberar(actorId, pacienteId) {
    this.ultimos.delete(`${actorId}|${pacienteId}`);
  }

  purgar(t) {
    for (const [clave, ultimo] of this.ultimos) {
      if (t - ultimo >= this.ventanaMs) this.ultimos.delete(clave);
    }
    // Si todas siguen vigentes (muchísimos pares a la vez), se vacía: a lo
    // más se repite un registro.
    if (this.ultimos.size >= this.maximo) this.ultimos.clear();
  }
}

// --- Consulta del admin: GET /api/admin/bitacora ---

const ZONA_HORARIA = 'America/Mexico_City';
const LIMITE_POR_DEFECTO = 100;
const LIMITE_MAXIMO = 200;
const FORMATO_DIA = /^\d{4}-\d{2}-\d{2}$/;
const FORMATO_UID = /^[A-Za-z0-9_-]{1,50}$/;
const CAMPOS_FILTRO = ['desde', 'hasta', 'usuario', 'accion', 'antes_de', 'limite'];

function diaValido(texto) {
  if (!FORMATO_DIA.test(texto)) return false;
  const d = new Date(`${texto}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === texto;
}

/**
 * Filtros de la query string. Todos opcionales; `desde` y `hasta` son días
 * locales (America/Mexico_City) inclusivos; `usuario` es un uid y busca tanto
 * en quien hizo la acción como en quien la recibió; `antes_de` es el cursor
 * (id de la última fila ya mostrada). Lanza ValidationError (400).
 */
function validarFiltrosBitacora(query = {}) {
  const extra = Object.keys(query).filter((k) => !CAMPOS_FILTRO.includes(k));
  if (extra.length > 0) throw new ValidationError(`Filtro no reconocido: ${extra.join(', ')}.`);
  const repetido = CAMPOS_FILTRO.find((k) => Array.isArray(query[k]));
  if (repetido) throw new ValidationError(`El filtro '${repetido}' va una sola vez.`);
  const texto = (k) => (typeof query[k] === 'string' && query[k].trim() !== '' ? query[k].trim() : null);

  const filtros = { desde: texto('desde'), hasta: texto('hasta'), usuario: texto('usuario'), accion: texto('accion') };
  for (const k of ['desde', 'hasta']) {
    if (filtros[k] !== null && !diaValido(filtros[k])) {
      throw new ValidationError(`'${k}' debe ser una fecha AAAA-MM-DD.`);
    }
  }
  if (filtros.desde && filtros.hasta && filtros.desde > filtros.hasta) {
    throw new ValidationError("'desde' no puede ser posterior a 'hasta'.");
  }
  if (filtros.usuario !== null && !FORMATO_UID.test(filtros.usuario)) {
    throw new ValidationError("'usuario' no es un identificador válido.");
  }
  if (filtros.accion !== null && !ACCIONES.includes(filtros.accion)) {
    throw new ValidationError("'accion' no es una acción de la bitácora.");
  }

  const entero = (k, min, max, porDefecto) => {
    const t = texto(k);
    if (t === null) return porDefecto;
    if (!/^\d+$/.test(t) || Number(t) < min || Number(t) > max) {
      throw new ValidationError(`'${k}' debe ser un entero entre ${min} y ${max}.`);
    }
    return Number(t);
  };
  filtros.antes_de = entero('antes_de', 1, Number.MAX_SAFE_INTEGER, null);
  filtros.limite = entero('limite', 1, LIMITE_MAXIMO, LIMITE_POR_DEFECTO);
  return filtros;
}

/**
 * SQL y parámetros de la consulta. Pide `limite + 1` filas: si llega la de
 * más, hay otra página (ver paginaBitacora). Más recientes primero.
 */
function consultaBitacora(filtros) {
  const condiciones = [];
  const params = [];
  const p = (valor) => {
    params.push(valor);
    return `$${params.length}`;
  };
  // La zona solo entra si hay fechas: un parámetro que el SQL no usa hace
  // fallar a Postgres ("could not determine data type of parameter $1").
  let zona = null;
  const pZona = () => zona ?? (zona = p(ZONA_HORARIA));
  if (filtros.desde) {
    const z = pZona();
    condiciones.push(`b.fecha >= (${p(filtros.desde)}::date)::timestamp AT TIME ZONE ${z}`);
  }
  if (filtros.hasta) {
    const z = pZona();
    condiciones.push(`b.fecha < (${p(filtros.hasta)}::date + 1)::timestamp AT TIME ZONE ${z}`);
  }
  if (filtros.usuario) {
    const u = p(filtros.usuario);
    condiciones.push(`(b.actor_id = ${u} OR b.objetivo_id = ${u})`);
  }
  if (filtros.accion) condiciones.push(`b.accion = ${p(filtros.accion)}`);
  if (filtros.antes_de) condiciones.push(`b.id < ${p(filtros.antes_de)}`);
  const limite = p(filtros.limite + 1);

  const sql = `
    SELECT b.id, b.fecha, b.accion, b.detalle,
      b.actor_id, b.actor_rol, a.nombre AS actor_nombre,
      b.objetivo_id, o.nombre AS objetivo_nombre, o.rol AS objetivo_rol
    FROM bitacora b
    LEFT JOIN usuarios a ON a.id = b.actor_id
    LEFT JOIN usuarios o ON o.id = b.objetivo_id
    ${condiciones.length > 0 ? `WHERE ${condiciones.join(' AND ')}` : ''}
    ORDER BY b.id DESC
    LIMIT ${limite};`;
  return { sql, params };
}

/** `{ filas, siguiente }`: `siguiente` es el cursor para "Cargar más" o null. */
function paginaBitacora(filas, limite) {
  const hayMas = filas.length > limite;
  const pagina = hayMas ? filas.slice(0, limite) : filas;
  return { filas: pagina, siguiente: hayMas ? Number(pagina[pagina.length - 1].id) : null };
}

module.exports = {
  ACCIONES,
  RECURSOS,
  DETALLE_PERMITIDO,
  parametrosBitacora,
  registrar,
  DedupeAccesos,
  validarFiltrosBitacora,
  consultaBitacora,
  paginaBitacora,
};
