// Funciones puras para las sesiones de medición en el portal (Fase M1, portal).
// Sin React ni red: se prueban con Jest (sesiones.test.js).
//
// El driver `pg` devuelve las columnas `numeric` como texto ("42.46"); los
// enteros y los valores dentro de `serie` (jsonb) llegan como número. Aquí se
// convierte todo con Number(...), como ya se hace con las lecturas.

export const SESIONES_URL = 'https://tt-ansiedad-backend.onrender.com/api/sesiones';

// Malla de la serie que arma la app (ConfigMedicion.intervaloSerieSeg).
export const PASO_SERIE_SEG = 5;

const CAMPOS_NUMERICOS = [
  'duracion_total_seg', 'duracion_valida_seg',
  'hrv_rmssd', 'hrv_min', 'hrv_max',
  'bpm_promedio', 'bpm_min', 'bpm_max',
  'spo2_promedio', 'spo2_min', 'spo2_max',
  'indice_calidad',
];

/** Fila del backend → mismos campos, con números de verdad y la serie normalizada. */
export function normalizarSesion(fila) {
  const sesion = { ...fila };
  for (const campo of CAMPOS_NUMERICOS) {
    if (fila[campo] != null) sesion[campo] = Number(fila[campo]);
  }
  if (Array.isArray(fila.serie)) {
    sesion.serie = fila.serie
      .map((p) => ({ t: Number(p.t), bpm: Number(p.bpm), spo2: Number(p.spo2), hrv: Number(p.hrv) }))
      .sort((a, b) => a.t - b.t);
  }
  return sesion;
}

const media = (valores) => (valores.length ? valores.reduce((a, v) => a + v, 0) / valores.length : null);

/**
 * Indicadores de las sesiones de los últimos `dias` días: cuántas hubo, el
 * promedio de su RMSSD y de su FC, y la fecha de la más reciente (de todas).
 * Datos descriptivos para el especialista; no interpretan nada.
 */
export function resumenSesiones(sesiones, { dias = 30, ahora = Date.now() } = {}) {
  const corte = ahora - dias * 24 * 60 * 60 * 1000;
  const recientes = sesiones.filter((s) => new Date(s.fecha_inicio).getTime() >= corte);
  const ultima = sesiones.reduce(
    (max, s) => (max == null || new Date(s.fecha_inicio) > new Date(max) ? s.fecha_inicio : max),
    null
  );
  return {
    total: recientes.length,
    hrvPromedio: media(recientes.map((s) => s.hrv_rmssd)),
    bpmPromedio: media(recientes.map((s) => s.bpm_promedio)),
    ultima,
  };
}

/** Datos de la gráfica "HRV y FC por sesión": últimos `dias` días, de la más antigua a la más reciente. */
export function datosTendencia(sesiones, { dias = 30, ahora = Date.now() } = {}) {
  const corte = ahora - dias * 24 * 60 * 60 * 1000;
  return sesiones
    .filter((s) => new Date(s.fecha_inicio).getTime() >= corte)
    .sort((a, b) => new Date(a.fecha_inicio) - new Date(b.fecha_inicio))
    .map((s) => ({
      x: fechaCorta(s.fecha_inicio),
      hrv: s.hrv_rmssd,
      bpm: s.bpm_promedio,
    }));
}

/**
 * Serie para graficar CORTADA en los huecos (vista del especialista): donde
 * dos puntos seguidos están separados más de un paso de la malla, se inserta
 * un punto con valores null, y Recharts corta ahí la línea. La app del
 * paciente hace lo contrario (línea continua).
 */
export function serieConCortes(serie, paso = PASO_SERIE_SEG) {
  const resultado = [];
  serie.forEach((p, i) => {
    if (i > 0 && p.t - serie[i - 1].t > paso) {
      resultado.push({ t: serie[i - 1].t + paso, bpm: null, spo2: null, hrv: null });
    }
    resultado.push(p);
  });
  return resultado;
}

/**
 * Tramos sin señal válida, en segundos de la sesión: cada punto cubre
 * [t, t + paso), así que un hueco va del final del punto anterior al inicio
 * del siguiente.
 */
export function huecosDeSerie(serie, paso = PASO_SERIE_SEG) {
  const huecos = [];
  for (let i = 1; i < serie.length; i++) {
    const desde = serie[i - 1].t + paso;
    if (serie[i].t > desde) huecos.push({ desde, hasta: serie[i].t });
  }
  return huecos;
}

/** Índice de calidad (0–1) como porcentaje entero. */
export const porcentajeCalidad = (indice) => (indice == null ? null : Math.round(indice * 100));

/** 125 → "2:05" */
export const minSeg = (segundos) => `${Math.floor(segundos / 60)}:${String(segundos % 60).padStart(2, '0')}`;

/** 45 → "45 s", 180 → "3 min", 214 → "3 min 34 s" */
export function duracionTexto(segundos) {
  if (segundos < 60) return `${segundos} s`;
  const resto = segundos % 60;
  return resto === 0 ? `${Math.floor(segundos / 60)} min` : `${Math.floor(segundos / 60)} min ${resto} s`;
}

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/** "13 oct" (hora local) */
export function fechaCorta(fecha) {
  const d = new Date(fecha);
  return `${d.getDate()} ${MESES[d.getMonth()]}`;
}

/** "13 oct 2026, 9:30" (hora local) */
export function fechaHora(fecha) {
  const d = new Date(fecha);
  return `${fechaCorta(d)} ${d.getFullYear()}, ${d.getHours()}:${String(d.getMinutes()).padStart(2, '0')}`;
}
