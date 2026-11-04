const { ValidationError, HttpError } = require('./errors');
const { diaLocal } = require('./linea_base');

// Notas clínicas del especialista (Bloque 2, paso 2: WEB-RF-27 / RN-15).
// Lógica pura, sin base: especialista.js la usa y notas.test.js la prueba.
//
// Decisión D1: una nota es del par paciente–especialista (como el chat): solo
// la ve el especialista que la escribió y mientras el paciente siga vinculado
// a él. El paciente nunca la ve y el admin nunca ve su contenido.
// Decisión D6: no se borran. Editar guarda la versión anterior en
// `notas_clinicas_versiones` (un trigger impide modificarlas).

const CONTENIDO_MAXIMO = 5000;
const ZONA_HORARIA = 'America/Mexico_City';
const FORMATO_DIA = /^\d{4}-\d{2}-\d{2}$/;
const DIA_MINIMO = '2000-01-01';

const CAMPOS_NUEVA = ['fecha', 'contenido'];
const CAMPOS_EDICION = ['fecha', 'contenido', 'version'];

function esObjetoPlano(valor) {
  return valor !== null && typeof valor === 'object' && !Array.isArray(valor);
}

/** Día AAAA-MM-DD real (no 2026-02-30). */
function diaValido(texto) {
  if (typeof texto !== 'string' || !FORMATO_DIA.test(texto)) return false;
  const d = new Date(`${texto}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === texto;
}

// Día clínico de la nota: no futuro (día local de Ciudad de México).
function validarFecha(valor, ahora) {
  if (!diaValido(valor)) throw new ValidationError('"fecha" debe ser una fecha AAAA-MM-DD.');
  if (valor < DIA_MINIMO) throw new ValidationError('"fecha" no es una fecha válida.');
  if (valor > diaLocal(ahora, ZONA_HORARIA)) throw new ValidationError('"fecha" no puede ser posterior a hoy.');
  return valor;
}

// Se cuentan caracteres reales (como char_length en la base), no unidades
// UTF-16: un emoji cuenta como uno.
function validarContenido(valor) {
  if (typeof valor !== 'string' || valor.trim() === '') {
    throw new ValidationError('La nota no puede estar vacía.');
  }
  const texto = valor.trim();
  if ([...texto].length > CONTENIDO_MAXIMO) {
    throw new ValidationError(`La nota no puede pasar de ${CONTENIDO_MAXIMO} caracteres.`);
  }
  return texto;
}

function revisarCampos(body, permitidos) {
  if (!esObjetoPlano(body)) throw new ValidationError('El cuerpo debe ser un objeto.');
  const extra = Object.keys(body).filter((k) => !permitidos.includes(k));
  if (extra.length > 0) throw new ValidationError(`Campo no reconocido: ${extra.join(', ')}.`);
}

/** POST /api/pacientes/:id/notas → { fecha, contenido }. */
function validarNotaNueva(body, ahora = new Date()) {
  revisarCampos(body, CAMPOS_NUEVA);
  return { fecha: validarFecha(body.fecha, ahora), contenido: validarContenido(body.contenido) };
}

/**
 * PUT /api/pacientes/:id/notas/:notaId → { fecha, contenido, version }.
 * `version` es la que el especialista tenía en pantalla: si otra pestaña ya
 * la editó, la edición se rechaza con 409 (ver decidirEdicion).
 */
function validarEdicionNota(body, ahora = new Date()) {
  revisarCampos(body, CAMPOS_EDICION);
  if (!Number.isInteger(body.version) || body.version < 1) {
    throw new ValidationError('"version" debe ser un entero positivo.');
  }
  return { fecha: validarFecha(body.fecha, ahora), contenido: validarContenido(body.contenido), version: body.version };
}

/**
 * Compara la nota guardada (bloqueada FOR UPDATE) con la edición. Lanza 409
 * si la versión no coincide. Devuelve false si no cambia nada (no se crea
 * una versión vacía ni se registra en la bitácora).
 */
function decidirEdicion(actual, datos) {
  if (actual.version !== datos.version) {
    throw new HttpError(
      'Esta nota cambió desde que la abriste (quizá en otra pestaña). Recarga para ver la versión actual.',
      409,
      'nota_desactualizada'
    );
  }
  return actual.fecha !== datos.fecha || actual.contenido !== datos.contenido;
}

// --- SQL --- `fecha` sale como texto: un `date` de pg llega como Date a la
// medianoche del servidor y cambiaría de día al serializarse.

const COLUMNAS_NOTA = `id, to_char(fecha, 'YYYY-MM-DD') AS fecha, contenido, version, creada_en, editada_en`;

const LISTAR_NOTAS = `
  SELECT ${COLUMNAS_NOTA}
  FROM notas_clinicas
  WHERE paciente_id = $1 AND especialista_id = $2
  ORDER BY fecha DESC, creada_en DESC
  LIMIT 500;`;

const INSERTAR_NOTA = `
  INSERT INTO notas_clinicas (paciente_id, especialista_id, fecha, contenido)
  VALUES ($1, $2, $3, $4)
  RETURNING ${COLUMNAS_NOTA};`;

// Del par (D1): una nota de otro especialista o de otro paciente es 404.
const BLOQUEAR_NOTA = `
  SELECT ${COLUMNAS_NOTA}
  FROM notas_clinicas
  WHERE id = $1 AND paciente_id = $2 AND especialista_id = $3
  FOR UPDATE;`;

// La versión que se reemplaza se escribió en su editada_en (o al crearse).
const GUARDAR_VERSION_ANTERIOR = `
  INSERT INTO notas_clinicas_versiones (nota_id, version, fecha, contenido, escrita_en)
  SELECT id, version, fecha, contenido, COALESCE(editada_en, creada_en)
  FROM notas_clinicas WHERE id = $1;`;

const ACTUALIZAR_NOTA = `
  UPDATE notas_clinicas
  SET fecha = $2, contenido = $3, version = version + 1, editada_en = now()
  WHERE id = $1
  RETURNING ${COLUMNAS_NOTA};`;

const EXISTE_NOTA = `
  SELECT 1 FROM notas_clinicas WHERE id = $1 AND paciente_id = $2 AND especialista_id = $3;`;

const LISTAR_VERSIONES = `
  SELECT version, to_char(fecha, 'YYYY-MM-DD') AS fecha, contenido, escrita_en, reemplazada_en
  FROM notas_clinicas_versiones
  WHERE nota_id = $1
  ORDER BY version DESC;`;

module.exports = {
  CONTENIDO_MAXIMO,
  diaValido,
  validarNotaNueva,
  validarEdicionNota,
  decidirEdicion,
  LISTAR_NOTAS,
  INSERTAR_NOTA,
  BLOQUEAR_NOTA,
  GUARDAR_VERSION_ANTERIOR,
  ACTUALIZAR_NOTA,
  EXISTE_NOTA,
  LISTAR_VERSIONES,
};
