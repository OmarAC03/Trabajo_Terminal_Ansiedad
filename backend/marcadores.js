const { ValidationError } = require('./errors');

// Marcadores clínicos en la línea de tiempo (Bloque 2, paso 3: WEB-RF-28).
// Lógica pura, sin base: especialista.js la usa y marcadores.test.js la
// prueba. Un marcador es un evento con fecha y hora que el especialista
// anota sobre la gráfica de HRV/FC (consulta, periodo de exámenes, …).
//
// Igual que las notas, son del par paciente–especialista (D1). A diferencia
// de ellas, su autor sí puede borrarlos, y el borrado queda en la bitácora (D6).

// Decisión D4: los mismos valores que el CHECK de `marcadores_clinicos`.
const TIPOS_MARCADOR = Object.freeze(['consulta', 'periodo_examenes', 'evento_personal', 'intervencion', 'otro']);
const DESCRIPCION_MAXIMA = 140;
const CAMPOS = ['fecha', 'tipo', 'descripcion'];
const FORMATO_FECHA_ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})$/;
const MARGEN_FUTURO_MS = 5 * 60 * 1000; // reloj del navegador adelantado
const FECHA_MINIMA = Date.parse('2000-01-01T00:00:00Z');

function validarFecha(valor, ahora) {
  if (typeof valor !== 'string' || !FORMATO_FECHA_ISO.test(valor) || Number.isNaN(Date.parse(valor))) {
    throw new ValidationError('"fecha" debe ser una fecha y hora ISO 8601 con zona (p. ej. 2026-11-04T10:30:00-06:00).');
  }
  const t = Date.parse(valor);
  if (t < FECHA_MINIMA) throw new ValidationError('"fecha" no es una fecha válida.');
  if (t > ahora.getTime() + MARGEN_FUTURO_MS) throw new ValidationError('"fecha" no puede ser posterior a ahora.');
  return new Date(t).toISOString();
}

/** POST /api/pacientes/:id/marcadores → { fecha, tipo, descripcion|null }. */
function validarMarcadorNuevo(body, ahora = new Date()) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw new ValidationError('El cuerpo debe ser un objeto.');
  }
  const extra = Object.keys(body).filter((k) => !CAMPOS.includes(k));
  if (extra.length > 0) throw new ValidationError(`Campo no reconocido: ${extra.join(', ')}.`);

  if (!TIPOS_MARCADOR.includes(body.tipo)) {
    throw new ValidationError(`"tipo" debe ser uno de: ${TIPOS_MARCADOR.join(', ')}.`);
  }
  let descripcion = null;
  if (body.descripcion !== undefined && body.descripcion !== null) {
    if (typeof body.descripcion !== 'string') throw new ValidationError('"descripcion" debe ser texto.');
    descripcion = body.descripcion.trim() || null;
    if (descripcion && [...descripcion].length > DESCRIPCION_MAXIMA) {
      throw new ValidationError(`"descripcion" no puede pasar de ${DESCRIPCION_MAXIMA} caracteres.`);
    }
  }
  return { fecha: validarFecha(body.fecha, ahora), tipo: body.tipo, descripcion };
}

// --- SQL --- Todo filtrado por el par (D1).

const COLUMNAS_MARCADOR = 'id, fecha, tipo, descripcion, creado_en';

const LISTAR_MARCADORES = `
  SELECT ${COLUMNAS_MARCADOR}
  FROM marcadores_clinicos
  WHERE paciente_id = $1 AND especialista_id = $2
  ORDER BY fecha ASC
  LIMIT 500;`;

const INSERTAR_MARCADOR = `
  INSERT INTO marcadores_clinicos (paciente_id, especialista_id, fecha, tipo, descripcion)
  VALUES ($1, $2, $3, $4, $5)
  RETURNING ${COLUMNAS_MARCADOR};`;

// Solo su autor (el especialista del par) lo borra; uno ajeno es 404.
const BORRAR_MARCADOR = `
  DELETE FROM marcadores_clinicos
  WHERE id = $1 AND paciente_id = $2 AND especialista_id = $3
  RETURNING id;`;

module.exports = {
  TIPOS_MARCADOR,
  DESCRIPCION_MAXIMA,
  validarMarcadorNuevo,
  LISTAR_MARCADORES,
  INSERTAR_MARCADOR,
  BORRAR_MARCADOR,
};
