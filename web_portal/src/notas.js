// Notas clínicas del especialista en el portal (Bloque 2, paso 2: WEB-RF-27 /
// RN-15). Funciones puras, sin React ni red: se prueban con Jest
// (notas.test.js). Las rutas son de backend/especialista.js.
//
// Solo las ve quien las escribió, mientras el paciente siga vinculado a él
// (decisión D1). El paciente nunca las ve. No se borran: cada edición guarda
// la versión anterior (D6).

import { API_BASE } from './config';

export const CONTENIDO_MAXIMO = 5000;
const ZONA_HORARIA = 'America/Mexico_City';

export const notasUrl = (pacienteId) => `${API_BASE}/api/pacientes/${pacienteId}/notas`;

/** Día AAAA-MM-DD en Ciudad de México (el mismo corte que el backend). */
export function diaLocal(fecha = new Date()) {
  return new Intl.DateTimeFormat('en-CA', { timeZone: ZONA_HORARIA, year: 'numeric', month: '2-digit', day: '2-digit' })
    .format(new Date(fecha));
}

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/**
 * '2026-11-04' → '4 nov 2026'. Sin `new Date(texto)`: eso lo leería como
 * medianoche UTC y en México saldría el día anterior.
 */
export function textoDia(dia) {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dia || '');
  if (!m) return dia || '';
  return `${Number(m[3])} ${MESES[Number(m[2]) - 1]} ${m[1]}`;
}

/** Largo en caracteres reales (como el backend y char_length). */
export const largo = (texto) => [...(texto || '')].length;

/** Mensaje si el borrador no se puede guardar; '' si está bien. */
export function errorBorrador({ fecha, contenido }, hoy = diaLocal()) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(fecha || '')) return 'Elige la fecha de la nota.';
  if (fecha > hoy) return 'La fecha no puede ser posterior a hoy.';
  if (!(contenido || '').trim()) return 'Escribe el contenido de la nota.';
  if (largo(contenido.trim()) > CONTENIDO_MAXIMO) return `La nota no puede pasar de ${CONTENIDO_MAXIMO} caracteres.`;
  return '';
}

/** ¿Cambió algo respecto a la nota guardada? (sin cambios no se envía). */
export const hayCambios = (nota, borrador) =>
  nota.fecha !== borrador.fecha || nota.contenido !== (borrador.contenido || '').trim();

/** Línea de estado bajo cada nota. `formato` da la fecha y hora. */
export function textoVersion(nota, formato) {
  if (!nota.editada_en || nota.version <= 1) return `Escrita el ${formato(nota.creada_en)}`;
  return `Versión ${nota.version} · editada el ${formato(nota.editada_en)}`;
}

/** Mensaje de error de una petición de notas. */
export function mensajeError(error, porDefecto) {
  const r = error?.response;
  if (r?.status === 409) return r.data?.error || 'La nota cambió desde que la abriste. Se recargó la versión actual.';
  if (r?.status === 403) return 'Este paciente no está vinculado a tu cuenta.';
  return r?.data?.error || porDefecto;
}
