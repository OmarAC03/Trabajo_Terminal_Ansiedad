// GAD-7 periódico en el portal (Fase M5a, paso 5). Funciones puras: se
// prueban con Jest (gad7.test.js).
//
// El backend (gad7.js / gad7_vista.js) ya manda el puntaje, la severidad
// ('minima' | 'leve' | 'moderada' | 'grave') y `valorar` (≥ 10) de cada
// respuesta; aquí solo se elige el texto visible. Son las categorías del
// instrumento (Spitzer et al., 2006), nunca Normal/Elevados/Altos: esas son de
// los indicadores fisiológicos, y para no confundirlas el GAD-7 va en tonos
// neutros (severidad en gris, acento violeta), nunca con el semáforo.
// Instrumento de tamizaje, no diagnóstico. Solo lo ve el especialista: el
// paciente nunca recibe su resultado.

import { API_BASE } from './config';
import { fechaCorta } from './sesiones';

export const GAD7_URL = `${API_BASE}/api/gad7`;

// Texto `gad7-es-v1`, copiado EXACTO de app_ansiedad/lib/contenido/
// gad7_textos.dart (García-Campayo et al., 2010). Si cambia una palabra,
// cambia también la versión, en la app, el backend y aquí.
export const VERSION_GAD7 = 'gad7-es-v1';

export const ITEMS_GAD7 = [
  'Sentirse nervioso, ansioso o muy tenso',
  'No poder detenerse o controlar la preocupación',
  'Preocuparse demasiado por cosas diferentes',
  'Dificultad para relajarse',
  'Ser tan inquieto que es difícil quedarse quieto',
  'Molestarse o irritarse con facilidad',
  'Sentir miedo, como si algo horrible pudiera suceder',
];

// El índice es el valor (0–3).
export const OPCIONES_GAD7 = ['De nada', 'Varios días', 'Más de la mitad de los días', 'Casi todos los días'];

export const OPCIONES_DIFICULTAD = ['No es nada difícil', 'Algo difícil', 'Muy difícil', 'Extremadamente difícil'];

export const PUNTAJE_MAXIMO = 21;
export const CORTE_VALORAR = 10;

// Líneas de referencia de la gráfica: dónde empieza cada tramo.
export const REFERENCIAS_GAD7 = [
  { valor: 5, texto: 'Leve' },
  { valor: 10, texto: 'Moderada' },
  { valor: 15, texto: 'Grave' },
];

// Tonos de src/ui/ (Badge, chip del icono). Nunca 'normal' | 'elevados' |
// 'altos'. COLOR_GAD7 = --color-violet de tokens.css, para Recharts.
export const TONO_SEVERIDAD = 'neutral';
export const TONO_GAD7 = 'violet';
export const COLOR_GAD7 = '#7c3aed';

const SEVERIDADES = {
  minima: 'Mínima',
  leve: 'Leve',
  moderada: 'Moderada',
  grave: 'Grave',
};

/** 'moderada' → "Moderada"; desconocida o null → "—". */
export const textoSeveridad = (clave) => SEVERIDADES[clave] ?? '—';

/** 12 → "12 / 21"; null → "—". */
export const formatoPuntaje = (p) => (p == null ? '—' : `${p} / ${PUNTAJE_MAXIMO}`);

const DIAS_SEMANA = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/**
 * Día local 'YYYY-MM-DD' (el `proxima_fecha` del backend) → "jue 6 nov".
 * Se arma con sus partes: `new Date('2026-11-06')` lo leería como medianoche
 * UTC, y en México saldría el día anterior.
 */
export function fechaDia(dia) {
  const [a, m, d] = String(dia).split('-').map(Number);
  const fecha = new Date(a, m - 1, d);
  return `${DIAS_SEMANA[fecha.getDay()]} ${d} ${MESES[m - 1]}`;
}

/**
 * Cuándo le toca el próximo cuestionario, a partir del `estado` de
 * GET /api/gad7: "Le toca responder", "Aún no responde · le toca" (nunca ha
 * respondido) o "Próximo en N días · desde el jue 6 nov".
 */
export function textoProximo(estado) {
  if (!estado) return null;
  if (estado.toca) return estado.ultima_respuesta ? 'Le toca responder' : 'Aún no responde · le toca';
  const n = estado.dias_restantes;
  return `Próximo en ${n} ${n === 1 ? 'día' : 'días'} · desde el ${fechaDia(estado.proxima_fecha)}`;
}

/**
 * La pregunta de dificultad. Sin respuesta puede ser por dos motivos: la app
 * no la pregunta si todos los ítems fueron "De nada" (puntaje 0), o el
 * paciente eligió no responderla.
 */
export function textoDificultad(dificultad, puntaje) {
  if (dificultad != null) return OPCIONES_DIFICULTAD[dificultad] ?? '—';
  return puntaje === 0 ? 'No se preguntó (no marcó ningún problema)' : 'Prefirió no responder';
}

/** Los 7 ítems de una respuesta: número, texto, valor y opción elegida. */
export function detalleItems(respuesta) {
  return ITEMS_GAD7.map((texto, i) => {
    const valor = respuesta.items?.[i] ?? null;
    return { numero: i + 1, texto, valor, opcion: valor == null ? '—' : OPCIONES_GAD7[valor] ?? '—' };
  });
}

/** Puntos de la gráfica del historial, de la respuesta más vieja a la más reciente. */
export function datosGrafica(respuestas) {
  return [...respuestas]
    .sort((a, b) => new Date(a.fecha_respuesta) - new Date(b.fecha_respuesta))
    .map((r) => ({
      id: r.id,
      x: fechaCorta(r.fecha_respuesta),
      fecha: r.fecha_respuesta,
      puntaje: r.puntaje,
      severidad: r.severidad,
      valorar: r.valorar,
    }));
}

/**
 * Celda "GAD-7" de la tabla de pacientes, con los campos `ultimo_gad7_*` y
 * `gad7_toca` de GET /api/pacientes. null si nunca ha respondido.
 */
export function resumenTabla(paciente) {
  if (!paciente.ultimo_gad7_fecha || paciente.ultimo_gad7_puntaje == null) return null;
  return {
    puntaje: Number(paciente.ultimo_gad7_puntaje),
    severidad: textoSeveridad(paciente.ultimo_gad7_severidad),
    valorar: Boolean(paciente.ultimo_gad7_valorar),
    fecha: paciente.ultimo_gad7_fecha,
    toca: Boolean(paciente.gad7_toca),
  };
}
