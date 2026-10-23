// GAD-7 periódico (Fase M5a, DESARROLLO_FUNDAMENTADO.md §4.2). Lógica pura,
// sin base de datos ni Express, para probarla con `node --test`
// (gad7.test.js).
//
// - Puntaje = suma de los 7 ítems (cada uno 0–3) → 0–21. La pregunta de
//   dificultad NO suma.
// - Severidad con los cortes de Spitzer et al. (2006): 0–4 mínima, 5–9 leve,
//   10–14 moderada, 15–21 grave. Son las categorías del instrumento, nunca
//   Normal/Elevados/Altos (esas son de los indicadores fisiológicos).
// - Puntaje ≥ 10 → "valorar": el portal lo marca para el especialista (§2.3).
// - Intervalo de 14 días por FECHA LOCAL del paciente: quien respondió el día
//   D (en México) vuelve a responder desde el día D + 14, a cualquier hora.
//   Si nunca ha respondido, le toca hoy.
//
// El puntaje y la severidad no se guardan en la base: se calculan al leer.

const { diaLocal, sumarDias } = require('./linea_base');

const CONFIG_GAD7 = Object.freeze({
  version: 'gad7-es-v1', // texto en español usado (García-Campayo et al., 2010)
  numItems: 7,
  valorMaximoItem: 3,
  intervaloDias: 14,
  corteValorar: 10,
  zonaHoraria: 'America/Mexico_City',
});

// Severidad por puntaje máximo de cada tramo (Spitzer et al., 2006).
const SEVERIDADES = Object.freeze([
  { hasta: 4, clave: 'minima' },
  { hasta: 9, clave: 'leve' },
  { hasta: 14, clave: 'moderada' },
  { hasta: 21, clave: 'grave' },
]);

/** Los 7 ítems de una fila de `respuestas_gad7` (columnas item1…item7). */
function itemsDeFila(fila) {
  return Array.from({ length: CONFIG_GAD7.numItems }, (_, i) => Number(fila[`item${i + 1}`]));
}

/** Suma de los 7 ítems (0–21). */
function puntaje(items) {
  if (!Array.isArray(items) || items.length !== CONFIG_GAD7.numItems) {
    throw new Error(`El GAD-7 tiene ${CONFIG_GAD7.numItems} ítems.`);
  }
  return items.reduce((suma, v) => suma + v, 0);
}

/** 'minima' | 'leve' | 'moderada' | 'grave' según el puntaje. */
function severidad(p) {
  const tramo = SEVERIDADES.find((s) => p <= s.hasta);
  if (!tramo || p < 0) throw new Error(`Puntaje GAD-7 fuera de rango: ${p}`);
  return tramo.clave;
}

/** Puntaje que el especialista debe valorar (≥ 10). */
function valorar(p, config = CONFIG_GAD7) {
  return p >= config.corteValorar;
}

function diasEntre(desde, hasta) {
  return Math.round((Date.parse(`${hasta}T00:00:00Z`) - Date.parse(`${desde}T00:00:00Z`)) / 86400000);
}

/**
 * ¿Le toca responder? `ultimaFecha` es la `fecha_respuesta` más reciente del
 * paciente (o null si nunca respondió). Devuelve:
 * - toca: puede responder hoy;
 * - proxima_fecha: día local ('YYYY-MM-DD') desde el que puede responder
 *   (hoy si nunca respondió o si ya le toca y no lo ha hecho);
 * - dias_restantes: días que faltan para proxima_fecha (0 si ya le toca).
 */
function estadoGad7(ultimaFecha, ahora = new Date(), config = CONFIG_GAD7) {
  const hoy = diaLocal(ahora, config.zonaHoraria);
  if (ultimaFecha == null) {
    return { toca: true, proxima_fecha: hoy, dias_restantes: 0 };
  }
  const proxima = sumarDias(diaLocal(ultimaFecha, config.zonaHoraria), config.intervaloDias);
  const restantes = Math.max(0, diasEntre(hoy, proxima));
  return {
    toca: restantes === 0,
    proxima_fecha: restantes === 0 ? hoy : proxima,
    dias_restantes: restantes,
  };
}

/** La `fecha_respuesta` más reciente de una lista de filas (o null). */
function ultimaFechaDe(filas) {
  let ultima = null;
  for (const f of filas) {
    if (ultima === null || new Date(f.fecha_respuesta) > new Date(ultima)) ultima = f.fecha_respuesta;
  }
  return ultima;
}

module.exports = {
  CONFIG_GAD7,
  SEVERIDADES,
  itemsDeFila,
  puntaje,
  severidad,
  valorar,
  estadoGad7,
  ultimaFechaDe,
};
