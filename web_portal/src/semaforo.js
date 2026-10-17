// Estado de los indicadores fisiológicos contra la línea base INDIVIDUAL del
// paciente (Fase M3), para la vista del especialista. Funciones puras: se
// prueban con Jest (semaforo.test.js).
//
// El backend (linea_base.js) manda `estado` = 'normal' | 'elevados' | 'altos'
// o null, con `motivo_sin_estado` ('calibrando' | 'calidad_baja') y `etapa`
// ('calibrando' | 'preliminar' | 'consolidada'). Aquí solo se elige el texto
// visible y el tono: lenguaje de indicadores, nunca de diagnóstico
// (MARCO_ALCANCE_Y_LENGUAJE.md, sección 2). El paciente nunca recibe estas
// etiquetas; solo las ve el especialista en el portal.
//
// Reemplaza al semáforo de umbrales fijos ('Alta' | 'Moderada' | 'Baja'),
// retirado en el refactor del Dashboard por no tener fundamento
// (DESARROLLO_FUNDAMENTADO.md §2). Colores de src/ui/tokens.css.

// `color`: los mismos hex que --color-normal / -elevados / -altos de
// tokens.css, para lo que no puede usar una clase (puntos de Recharts).
const ESTADOS = {
  normal: { texto: 'Normal', tono: 'normal', color: '#16a34a' },
  elevados: { texto: 'Elevados', tono: 'elevados', color: '#d97706' },
  altos: { texto: 'Altos', tono: 'altos', color: '#dc2626' },
};
const COLOR_SIN_ESTADO = '#94a3b8'; // --color-sin-datos

const SIN_ESTADO = {
  calibrando: 'Calibrando',
  calidad_baja: 'Calidad insuficiente',
};

const ETAPAS = {
  calibrando: 'Calibrando',
  preliminar: 'Preliminar',
  consolidada: 'Consolidada',
};

/** 'elevados' → "Elevados"; null o desconocido → null. */
export const textoEstado = (estado) => ESTADOS[estado]?.texto ?? null;

/** Tono de los componentes de src/ui/ (Badge, ui-legend-dot...). */
export const tonoEstado = (estado) => ESTADOS[estado]?.tono ?? 'sin-datos';

/** Hex del estado para gráficas; gris si no hay estado. */
export const colorEstado = (estado) => ESTADOS[estado]?.color ?? COLOR_SIN_ESTADO;

/** Por qué una sesión no tiene estado: "Calibrando" / "Calidad insuficiente". */
export const textoSinEstado = (motivo) => SIN_ESTADO[motivo] ?? 'Sin estado';

/** 'preliminar' → "Preliminar". */
export const textoEtapa = (etapa) => ETAPAS[etapa] ?? '—';

/**
 * Lo que muestra una etiqueta de estado a partir de una `evaluacion` del
 * backend (o null si no la hay): texto, tono y si es un estado de verdad o
 * un "sin estado" (que se pinta en gris, sin punto de color).
 */
export function etiquetaEvaluacion(evaluacion) {
  if (!evaluacion) return { texto: 'Sin estado', tono: 'sin-datos', conEstado: false };
  if (evaluacion.estado && ESTADOS[evaluacion.estado]) {
    return { texto: textoEstado(evaluacion.estado), tono: tonoEstado(evaluacion.estado), conEstado: true };
  }
  return { texto: textoSinEstado(evaluacion.motivo_sin_estado), tono: 'sin-datos', conEstado: false };
}

/**
 * Evaluación de la última sesión de un paciente, armada con los campos
 * `ultima_sesion_*` de GET /api/pacientes. null si nunca midió.
 */
export function evaluacionUltimaSesion(paciente) {
  if (!paciente.ultima_sesion) return null;
  return {
    estado: paciente.ultima_sesion_estado ?? null,
    etapa: paciente.ultima_sesion_etapa ?? null,
    motivo_sin_estado: paciente.ultima_sesion_motivo_sin_estado ?? null,
    fc_por_encima: paciente.ultima_sesion_fc_por_encima ?? null,
  };
}

/**
 * Texto de la calibración de un origen (GET /api/linea-base): "Calibrando:
 * día 2 de 7", "Preliminar · 5 días", "Consolidada · 7 días".
 */
export function textoCalibracion(c) {
  if (c.etapa === 'calibrando') return `Calibrando: día ${c.dia_calibracion} de ${c.dias_objetivo}`;
  return `${textoEtapa(c.etapa)} · ${c.n} ${c.n === 1 ? 'día' : 'días'}`;
}
