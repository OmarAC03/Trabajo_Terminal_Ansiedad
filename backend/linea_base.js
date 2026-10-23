// Línea base individual y estado del indicador (Fase M3,
// DESARROLLO_FUNDAMENTADO.md §2.2 y §3). Lógica pura, sin base de datos ni
// Express, para probarla con `node --test` (linea_base.test.js).
//
// Resumen de la fórmula:
// - Cada sesión aporta x = ln(RMSSD). Las sesiones de un mismo día local se
//   promedian: el día cuenta UNA vez para desbloquear la base.
// - Una sesión del día D se compara contra los últimos 7 días con medición
//   ANTERIORES a D (el propio día no entra), dentro de los 30 días naturales
//   previos, y solo del mismo `origen` (la simulación no contamina la base
//   del sensor).
// - Con < 3 días no hay estado (calibrando). De 3 a 6 días la base es
//   preliminar y la banda se estrecha de forma lineal; con 7, consolidada.
// - z = (x − media) / DE intraindividual (con piso). Normal si z ≥ −k1,
//   Elevados si −k2 ≤ z < −k1, Altos si z < −k2. Una HRV por encima de la
//   banda es Normal (más variabilidad = mejor regulación, §1.1).
// - La FC tiene su propia base (sin logaritmo) y solo ACOMPAÑA: marca
//   `fc_por_encima`, nunca cambia el estado. El SpO2 queda fuera (§2.3).

const CONFIG_LINEA_BASE = Object.freeze({
  version: 'm3-v1', // cambia si cambia cualquier parámetro de abajo
  zonaHoraria: 'America/Mexico_City', // el "día" es el del paciente, no UTC
  diasVentana: 7, // media móvil de 7 días (Plews et al., 2014)
  diasVencimiento: 30, // días más viejos no cuentan: se vuelve a calibrar
  diasMinimos: 3, // base preliminar desde 3 días distintos
  k1Preliminar: 1.5, // banda tolerante con pocos días...
  k1Consolidada: 1.0, // ...que se estrecha al consolidarse
  separacionAltos: 1.0, // k2 = k1 + 1
  // PROVISIONALES (sin fuente): se ajustan con los datos del simulador y del
  // sensor. El piso evita que, con 3 días casi iguales, el ruido marque todo.
  pisoDeLn: 0.10,
  pisoDeBpm: 3,
  calidadMinima: 0.60, // fracción de la sesión con señal válida
});

const ETAPAS = Object.freeze({
  calibrando: 'calibrando',
  preliminar: 'preliminar',
  consolidada: 'consolidada',
});

const ESTADOS = Object.freeze({
  normal: 'normal',
  elevados: 'elevados',
  altos: 'altos',
});

const MS_POR_DIA = 24 * 60 * 60 * 1000;
const formatosDia = new Map();

/** 'YYYY-MM-DD' del instante `fecha` en la zona horaria dada. */
function diaLocal(fecha, zonaHoraria) {
  if (!formatosDia.has(zonaHoraria)) {
    formatosDia.set(zonaHoraria, new Intl.DateTimeFormat('en-CA', {
      timeZone: zonaHoraria, year: 'numeric', month: '2-digit', day: '2-digit',
    }));
  }
  return formatosDia.get(zonaHoraria).format(new Date(fecha));
}

function sumarDias(dia, dias) {
  const [a, m, d] = dia.split('-').map(Number);
  return new Date(Date.UTC(a, m - 1, d) + dias * MS_POR_DIA).toISOString().slice(0, 10);
}

function media(valores) {
  return valores.reduce((s, v) => s + v, 0) / valores.length;
}

/** Desviación estándar muestral (n − 1); 0 con menos de 2 valores. */
function deMuestral(valores) {
  if (valores.length < 2) return 0;
  const m = media(valores);
  return Math.sqrt(valores.reduce((s, v) => s + (v - m) ** 2, 0) / (valores.length - 1));
}

// pg devuelve las columnas numeric como string ("42.46"): se convierten aquí
// para que el módulo acepte filas tal cual salen de la base.
function normalizarSesion(s) {
  return {
    id: s.id,
    fecha_inicio: s.fecha_inicio,
    origen: s.origen,
    hrv: Number(s.hrv_rmssd),
    bpm: Number(s.bpm_promedio),
    calidad: Number(s.indice_calidad),
  };
}

function entraEnBase(s, config) {
  return Number.isFinite(s.hrv) && s.hrv > 0
    && Number.isFinite(s.bpm) && s.bpm > 0
    && Number.isFinite(s.calidad) && s.calidad >= config.calidadMinima;
}

/** Valores diarios (media de ln RMSSD y de FC) de las sesiones que entran
 * en la base, de un solo origen, ordenados del día más viejo al más nuevo. */
function valoresPorDia(sesiones, origen, config) {
  const porDia = new Map();
  for (const fila of sesiones) {
    const s = normalizarSesion(fila);
    if (s.origen !== origen || !entraEnBase(s, config)) continue;
    const dia = diaLocal(s.fecha_inicio, config.zonaHoraria);
    if (!porDia.has(dia)) porDia.set(dia, { ln: [], bpm: [] });
    porDia.get(dia).ln.push(Math.log(s.hrv));
    porDia.get(dia).bpm.push(s.bpm);
  }
  return [...porDia.entries()]
    .sort(([a], [b]) => (a < b ? -1 : 1))
    .map(([dia, v]) => ({ dia, ln: media(v.ln), bpm: media(v.bpm), sesiones: v.ln.length }));
}

/** k1 de la banda según los días de la base: 1.5 con 3 días, baja en línea
 * recta hasta 1.0 con 7. */
function k1ParaDias(n, config) {
  if (n >= config.diasVentana) return config.k1Consolidada;
  const avance = (n - config.diasMinimos) / (config.diasVentana - config.diasMinimos);
  return config.k1Preliminar - (config.k1Preliminar - config.k1Consolidada) * avance;
}

/** Línea base para comparar una sesión del día `dia` (no incluye ese día). */
function lineaBaseAntesDe(sesiones, dia, origen, config = CONFIG_LINEA_BASE) {
  const desde = sumarDias(dia, -config.diasVencimiento);
  const dias = valoresPorDia(sesiones, origen, config)
    .filter((d) => d.dia < dia && d.dia >= desde)
    .slice(-config.diasVentana);
  const n = dias.length;
  const base = { origen, dia, n, dias: dias.map((d) => d.dia) };
  if (n < config.diasMinimos) {
    return { ...base, etapa: ETAPAS.calibrando };
  }

  const ln = dias.map((d) => d.ln);
  const bpm = dias.map((d) => d.bpm);
  const mediaLn = media(ln);
  const deLn = deMuestral(ln);
  const deLnUsada = Math.max(deLn, config.pisoDeLn);
  const mediaBpm = media(bpm);
  const deBpm = deMuestral(bpm);
  const deBpmUsada = Math.max(deBpm, config.pisoDeBpm);
  const k1 = k1ParaDias(n, config);

  return {
    ...base,
    etapa: n >= config.diasVentana ? ETAPAS.consolidada : ETAPAS.preliminar,
    media_ln: mediaLn,
    de_ln: deLn,
    de_ln_usada: deLnUsada,
    k1,
    k2: k1 + config.separacionAltos,
    // "Rango habitual" en ms, para el especialista.
    rango_hrv_ms: {
      min: Math.exp(mediaLn - k1 * deLnUsada),
      max: Math.exp(mediaLn + k1 * deLnUsada),
    },
    fc: {
      media: mediaBpm,
      de: deBpm,
      de_usada: deBpmUsada,
      limite_superior: mediaBpm + k1 * deBpmUsada,
    },
  };
}

/** Estado de UNA sesión contra la base de los días anteriores a ella.
 * `estado` es null si la base aún se calibra o si la sesión tiene calidad
 * insuficiente (`motivo_sin_estado` dice cuál). */
function evaluarSesion(fila, sesiones, config = CONFIG_LINEA_BASE) {
  const s = normalizarSesion(fila);
  const dia = diaLocal(s.fecha_inicio, config.zonaHoraria);
  const lineaBase = lineaBaseAntesDe(sesiones, dia, s.origen, config);
  const resultado = {
    sesion_id: s.id,
    dia,
    origen: s.origen,
    estado: null,
    motivo_sin_estado: null,
    z: null,
    fc_por_encima: null,
    linea_base: lineaBase,
    version: config.version,
  };

  if (!entraEnBase(s, config)) {
    return { ...resultado, motivo_sin_estado: 'calidad_baja' };
  }
  if (lineaBase.etapa === ETAPAS.calibrando) {
    return { ...resultado, motivo_sin_estado: 'calibrando' };
  }

  const z = (Math.log(s.hrv) - lineaBase.media_ln) / lineaBase.de_ln_usada;
  let estado = ESTADOS.normal;
  if (z < -lineaBase.k2) estado = ESTADOS.altos;
  else if (z < -lineaBase.k1) estado = ESTADOS.elevados;

  return {
    ...resultado,
    estado,
    z,
    fc_por_encima: s.bpm > lineaBase.fc.limite_superior,
  };
}

/** Evalúa todas las sesiones (cada una contra su propia base histórica). */
function evaluarSesiones(sesiones, config = CONFIG_LINEA_BASE) {
  return sesiones.map((s) => evaluarSesion(s, sesiones, config));
}

/** Progreso de calibración de un origen a la fecha `ahora`, para el mensaje
 * de la mascota. `etapa` y `dias_en_base` son los de la PRÓXIMA medición de
 * otro día (incluyen hoy); `dias_con_medicion` cuenta los días válidos de los
 * últimos 30, incluido hoy. */
function progresoCalibracion(sesiones, origen, ahora = new Date(), config = CONFIG_LINEA_BASE) {
  const hoy = diaLocal(ahora, config.zonaHoraria);
  const desde = sumarDias(hoy, -config.diasVencimiento);
  const todos = valoresPorDia(sesiones, origen, config).filter((d) => d.dia <= hoy);
  const recientes = todos.filter((d) => d.dia >= desde);
  const deHoy = recientes.find((d) => d.dia === hoy);
  const siguiente = lineaBaseAntesDe(sesiones, sumarDias(hoy, 1), origen, config);

  return {
    origen,
    hoy,
    dias_con_medicion: recientes.length,
    sesiones_validas_hoy: deHoy ? deHoy.sesiones : 0,
    hay_historial_vencido: todos.length > recientes.length,
    etapa: siguiente.etapa,
    dias_en_base: siguiente.n,
    version: config.version,
  };
}

module.exports = {
  CONFIG_LINEA_BASE,
  ETAPAS,
  ESTADOS,
  diaLocal,
  sumarDias,
  lineaBaseAntesDe,
  evaluarSesion,
  evaluarSesiones,
  progresoCalibracion,
};
