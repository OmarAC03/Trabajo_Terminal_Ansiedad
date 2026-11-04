const crypto = require('crypto');
const { ValidationError } = require('./errors');
const { diaValido } = require('./notas');
const { itemsDeFila, puntaje, severidad } = require('./gad7');

// Reporte de un paciente para exportar (Bloque 2, paso 4: WEB-RF-29 /
// RNF-WEB-08). Lógica pura, sin base: especialista.js la usa y
// reporte.test.js la prueba. El backend entrega los datos del periodo en
// JSON; el portal arma el CSV o la vista de impresión (PDF con el diálogo del
// navegador), sin bibliotecas GPL/AGPL.
//
// Decisión D3, versión seudonimizada: sin nombre, correo ni especialista; el
// paciente se identifica como `P-` + 8 hex del SHA-256 de su uid; sin texto
// libre (contexto de la EVA, descripción de los marcadores); las fechas se
// conservan. Es SEUDONIMIZADO, no anónimo: quien tenga los uid puede
// recalcular el identificador.
//
// Las notas clínicas no van en el reporte: es el registro de mediciones.

const ZONA_HORARIA = 'America/Mexico_City';
const CAMPOS = ['desde', 'hasta', 'formato', 'seudonimizado'];
const FORMATOS = ['csv', 'pdf'];
const DIAS_MAXIMOS = 366;
const DIA_MS = 24 * 60 * 60 * 1000;

/** `P-` + 8 hex del SHA-256 del uid (estable: el mismo paciente, el mismo id). */
function seudonimo(uid) {
  return `P-${crypto.createHash('sha256').update(String(uid)).digest('hex').slice(0, 8)}`;
}

/**
 * Query string de GET /api/pacientes/:id/reporte. `desde` y `hasta` son días
 * locales inclusivos (obligatorios, hasta 366 días); `formato` es lo que se
 * va a generar (solo para la bitácora); `seudonimizado` 'true' | 'false'.
 */
function validarReporte(query = {}) {
  const extra = Object.keys(query).filter((k) => !CAMPOS.includes(k));
  if (extra.length > 0) throw new ValidationError(`Parámetro no reconocido: ${extra.join(', ')}.`);
  const repetido = CAMPOS.find((k) => Array.isArray(query[k]));
  if (repetido) throw new ValidationError(`El parámetro '${repetido}' va una sola vez.`);

  const { desde, hasta, formato, seudonimizado } = query;
  for (const [k, v] of [['desde', desde], ['hasta', hasta]]) {
    if (!diaValido(v)) throw new ValidationError(`'${k}' debe ser una fecha AAAA-MM-DD.`);
  }
  if (desde > hasta) throw new ValidationError("'desde' no puede ser posterior a 'hasta'.");
  const dias = (Date.parse(`${hasta}T00:00:00Z`) - Date.parse(`${desde}T00:00:00Z`)) / DIA_MS + 1;
  if (dias > DIAS_MAXIMOS) throw new ValidationError(`El periodo no puede pasar de ${DIAS_MAXIMOS} días.`);
  if (!FORMATOS.includes(formato)) throw new ValidationError("'formato' debe ser 'csv' o 'pdf'.");
  if (seudonimizado !== 'true' && seudonimizado !== 'false') {
    throw new ValidationError("'seudonimizado' debe ser 'true' o 'false'.");
  }
  return { desde, hasta, formato, seudonimizado: seudonimizado === 'true' };
}

// --- SQL --- $1 paciente, $2 desde, $3 hasta, $4 zona (días locales
// inclusivos); los marcadores, además, $5 especialista (par D1).
const EN_RANGO = (col) =>
  `${col} >= ($2::date)::timestamp AT TIME ZONE $4 AND ${col} < ($3::date + 1)::timestamp AT TIME ZONE $4`;

const SESIONES_REPORTE = `
  SELECT s.id, s.fecha_inicio, s.origen, s.duracion_total_seg, s.duracion_valida_seg,
    s.hrv_rmssd, s.bpm_promedio, s.bpm_min, s.bpm_max, s.spo2_promedio, s.indice_calidad,
    e.valor AS eva_valor, e.contexto AS eva_contexto
  FROM sesiones_medicion s
  LEFT JOIN respuestas_eva e ON e.sesion_id = s.id
  WHERE s.paciente_id = $1 AND ${EN_RANGO('s.fecha_inicio')}
  ORDER BY s.fecha_inicio ASC;`;

const GAD7_REPORTE = `
  SELECT fecha_respuesta, item1, item2, item3, item4, item5, item6, item7
  FROM respuestas_gad7
  WHERE paciente_id = $1 AND ${EN_RANGO('fecha_respuesta')}
  ORDER BY fecha_respuesta ASC;`;

const MARCADORES_REPORTE = `
  SELECT fecha, tipo, descripcion
  FROM marcadores_clinicos
  WHERE paciente_id = $1 AND especialista_id = $5 AND ${EN_RANGO('fecha')}
  ORDER BY fecha ASC;`;

const parametrosReporte = (pacienteId, filtros) => [pacienteId, filtros.desde, filtros.hasta, ZONA_HORARIA];

const num = (v) => (v == null ? null : Number(v));

/**
 * El reporte, campo por campo (sin `...fila`: una columna nueva no se cuela).
 * `sesiones` ya traen `evaluacion` (la de server.js, vista del especialista).
 */
function armarReporte({ pacienteId, paciente, especialista, filtros, sesiones, gad7, marcadores, generadoEn = new Date() }) {
  const seud = filtros.seudonimizado;
  return {
    seudonimizado: seud,
    paciente: seud
      ? { id: seudonimo(pacienteId) }
      : { id: seudonimo(pacienteId), nombre: paciente?.nombre ?? null, email: paciente?.email ?? null },
    especialista: seud ? null : { nombre: especialista?.nombre ?? null },
    periodo: { desde: filtros.desde, hasta: filtros.hasta, zona_horaria: ZONA_HORARIA },
    generado_en: generadoEn.toISOString(),
    sesiones: sesiones.map((s) => ({
      fecha_inicio: s.fecha_inicio,
      origen: s.origen,
      duracion_total_seg: num(s.duracion_total_seg),
      duracion_valida_seg: num(s.duracion_valida_seg),
      hrv_rmssd: num(s.hrv_rmssd),
      bpm_promedio: num(s.bpm_promedio),
      bpm_min: num(s.bpm_min),
      bpm_max: num(s.bpm_max),
      spo2_promedio: num(s.spo2_promedio),
      indice_calidad: num(s.indice_calidad),
      eva_valor: num(s.eva_valor),
      ...(seud ? {} : { eva_contexto: s.eva_contexto ?? null }),
      estado: s.evaluacion?.estado ?? null,
      etapa: s.evaluacion?.etapa ?? null,
    })),
    gad7: gad7.map((g) => {
      const p = puntaje(itemsDeFila(g));
      return { fecha_respuesta: g.fecha_respuesta, puntaje: p, severidad: severidad(p) };
    }),
    marcadores: marcadores.map((m) => ({
      fecha: m.fecha,
      tipo: m.tipo,
      ...(seud ? {} : { descripcion: m.descripcion ?? null }),
    })),
  };
}

module.exports = {
  ZONA_HORARIA,
  DIAS_MAXIMOS,
  seudonimo,
  validarReporte,
  SESIONES_REPORTE,
  GAD7_REPORTE,
  MARCADORES_REPORTE,
  parametrosReporte,
  armarReporte,
};
