// Marcadores clínicos en la gráfica de HRV/FC (Bloque 2, paso 3: WEB-RF-28).
// Funciones puras, sin React ni red: se prueban con Jest
// (marcadores.test.js). Las rutas son de backend/especialista.js.
//
// Un marcador es un evento con fecha y hora (consulta, periodo de exámenes,
// …) que el especialista anota para leer la gráfica en contexto. Son del par
// paciente–especialista (D1); su autor los puede borrar (D6).

import { API_BASE } from './config';
import { fechaCorta } from './sesiones';

export const marcadoresUrl = (pacienteId) => `${API_BASE}/api/pacientes/${pacienteId}/marcadores`;

// Decisión D4: los mismos tipos que el CHECK de la tabla.
export const TIPOS_MARCADOR = [
  { id: 'consulta', etiqueta: 'Consulta' },
  { id: 'periodo_examenes', etiqueta: 'Periodo de exámenes' },
  { id: 'evento_personal', etiqueta: 'Evento personal' },
  { id: 'intervencion', etiqueta: 'Intervención' },
  { id: 'otro', etiqueta: 'Otro' },
];

export const DESCRIPCION_MAXIMA = 140;

export const textoTipo = (tipo) => TIPOS_MARCADOR.find((t) => t.id === tipo)?.etiqueta ?? tipo;

const DIA_MS = 24 * 60 * 60 * 1000;

/**
 * Marcadores de los últimos `dias` días para la gráfica, del más antiguo al
 * más reciente, con `t` (ms) y `numero` (1, 2, …) que se repite en la lista.
 */
export function marcadoresEnGrafica(marcadores, { dias = 30, ahora = Date.now() } = {}) {
  const corte = ahora - dias * DIA_MS;
  return marcadores
    .map((m) => ({ ...m, t: new Date(m.fecha).getTime() }))
    .filter((m) => m.t >= corte && m.t <= ahora + DIA_MS)
    .sort((a, b) => a.t - b.t)
    .map((m, i) => ({ ...m, numero: i + 1 }));
}

/**
 * Dominio del eje X (tiempo en ms) que abarca las sesiones y los marcadores,
 * con un margen a los lados para que el primer y el último punto no queden
 * pegados al borde. Con un solo instante, ±12 h.
 */
export function dominioTiempo(puntos, marcas = []) {
  const ts = [...puntos.map((p) => p.t), ...marcas.map((m) => m.t)].filter(Number.isFinite);
  if (ts.length === 0) return ['auto', 'auto'];
  const min = Math.min(...ts);
  const max = Math.max(...ts);
  const margen = Math.max((max - min) * 0.04, DIA_MS / 2);
  return [min - margen, max + margen];
}

/**
 * Marcas del eje X a medianoche local, cada 1, 2, 3, 7… días para no pasar
 * de `maximo` etiquetas.
 */
export function ticksDias([desde, hasta], maximo = 8) {
  if (!Number.isFinite(desde) || !Number.isFinite(hasta)) return undefined;
  const dias = (hasta - desde) / DIA_MS;
  const paso = [1, 2, 3, 5, 7, 14].find((p) => dias / p <= maximo) ?? 30;
  const inicio = new Date(desde);
  inicio.setHours(0, 0, 0, 0);
  if (inicio.getTime() < desde) inicio.setDate(inicio.getDate() + 1);
  const ticks = [];
  for (const d = inicio; d.getTime() <= hasta; d.setDate(d.getDate() + paso)) ticks.push(d.getTime());
  return ticks;
}

export const etiquetaTick = (t) => fechaCorta(t);

/** Valor de un <input type="datetime-local"> para un instante (hora local). */
export function valorLocal(fecha = new Date()) {
  const d = new Date(fecha);
  const dos = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${dos(d.getMonth() + 1)}-${dos(d.getDate())}T${dos(d.getHours())}:${dos(d.getMinutes())}`;
}

/** '2026-11-04T10:30' (hora local del navegador) → ISO con zona; null si no es válido. */
export function isoDesdeLocal(valor) {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(valor || '')) return null;
  const d = new Date(valor);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

/** Mensaje si el marcador no se puede guardar; '' si está bien. */
export function errorMarcador({ fecha, tipo, descripcion }, ahora = Date.now()) {
  if (!TIPOS_MARCADOR.some((t) => t.id === tipo)) return 'Elige el tipo de marcador.';
  const iso = isoDesdeLocal(fecha);
  if (!iso) return 'Elige la fecha y la hora.';
  if (new Date(iso).getTime() > ahora + 5 * 60 * 1000) return 'La fecha no puede ser posterior a ahora.';
  if ([...(descripcion || '').trim()].length > DESCRIPCION_MAXIMA) {
    return `La descripción no puede pasar de ${DESCRIPCION_MAXIMA} caracteres.`;
  }
  return '';
}
