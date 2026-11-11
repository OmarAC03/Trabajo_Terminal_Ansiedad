import { API_BASE } from './config';
import { diaLocal } from './notas';

// Sección Mensajes del portal (versión final, Fase 2): bandeja de
// conversaciones, separadores por día en el chat y la caja de texto. Lógica
// pura, probada en chat.test.js (se llama chat.js y no mensajes.js porque en
// Windows chocaría con el componente Mensajes.js). Las fechas siempre en hora
// de México, aunque la computadora del especialista tenga otra zona.

export const conversacionesUrl = `${API_BASE}/api/especialista/conversaciones`;

const ZONA_HORARIA = 'America/Mexico_City';
export const TEXTO_MAXIMO = 2000; // el mismo límite que valida el servidor
export const LINEAS_MAXIMAS = 5;

const partes = (fecha, opciones) =>
  Object.fromEntries(
    new Intl.DateTimeFormat('es-MX', { timeZone: ZONA_HORARIA, ...opciones })
      .formatToParts(new Date(fecha))
      .map((p) => [p.type, p.value])
  );

// Días de calendario entre dos 'AAAA-MM-DD' (b − a).
const diasEntre = (a, b) => Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86400000);

/**
 * Separador de día: "Hoy", "Ayer", "lunes 9 de noviembre" y, si no es el año
 * actual, "lunes 9 de noviembre de 2025".
 */
export function etiquetaDia(fecha, ahora = new Date()) {
  const dia = diaLocal(fecha);
  const hoy = diaLocal(ahora);
  const diferencia = diasEntre(dia, hoy);
  if (diferencia === 0) return 'Hoy';
  if (diferencia === 1) return 'Ayer';
  const p = partes(fecha, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  const base = `${p.weekday} ${p.day} de ${p.month}`;
  return dia.slice(0, 4) === hoy.slice(0, 4) ? base : `${base} de ${p.year}`;
}

/** "14:05" (24 h, hora de México). */
export function horaLocal(fecha) {
  if (!fecha) return '';
  const p = partes(fecha, { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
  return `${p.hour}:${p.minute}`;
}

/**
 * Mensajes (ya en orden cronológico) intercalados con un separador cada vez
 * que cambia el día: [{ tipo: 'dia', clave, etiqueta } | { tipo: 'mensaje', clave, mensaje }].
 */
export function conSeparadores(mensajes, ahora = new Date()) {
  const items = [];
  let diaAnterior = null;
  for (const m of mensajes) {
    const dia = diaLocal(m.fecha_envio);
    if (dia !== diaAnterior) {
      items.push({ tipo: 'dia', clave: `dia-${dia}`, etiqueta: etiquetaDia(m.fecha_envio, ahora) });
      diaAnterior = dia;
    }
    items.push({ tipo: 'mensaje', clave: m.id, mensaje: m });
  }
  return items;
}

/** Fecha corta para la bandeja: la hora si es de hoy, "Ayer" o "9 nov". */
export function fechaBandeja(fecha, ahora = new Date()) {
  if (!fecha) return '';
  const diferencia = diasEntre(diaLocal(fecha), diaLocal(ahora));
  if (diferencia === 0) return horaLocal(fecha);
  if (diferencia === 1) return 'Ayer';
  const p = partes(fecha, { day: 'numeric', month: 'short', year: 'numeric' });
  const mes = p.month.replace('.', '');
  return diaLocal(fecha).slice(0, 4) === diaLocal(ahora).slice(0, 4) ? `${p.day} ${mes}` : `${p.day} ${mes} ${p.year}`;
}

/** Línea de estado de una conversación de la bandeja. */
export function estadoConversacion(c) {
  if (c.pendiente) {
    return c.sin_responder > 1 ? `Pendiente de responder · ${c.sin_responder} mensajes` : 'Pendiente de responder';
  }
  if (c.ultimo_de === 'especialista') return 'Respondida';
  return 'Sin mensajes todavía';
}

/** Cuántas conversaciones esperan respuesta (la pastilla del menú). */
export const contarPendientes = (conversaciones) =>
  (conversaciones || []).filter((c) => c.pendiente).length;

/**
 * ¿Esta tecla envía el mensaje? Enter solo; Shift+Enter hace salto de línea.
 * Tampoco envía mientras se compone un carácter (acentos con teclas muertas,
 * IME), para no mandar el mensaje a medias.
 */
export function teclaEnvia(evento) {
  if (evento.key !== 'Enter') return false;
  if (evento.shiftKey || evento.altKey || evento.ctrlKey || evento.metaKey) return false;
  if (evento.isComposing || evento.nativeEvent?.isComposing || evento.keyCode === 229) return false;
  return true;
}

/**
 * Alto de la caja de texto: crece con el contenido de 1 a LINEAS_MAXIMAS
 * líneas y después hace scroll por dentro. Todo en píxeles; `relleno` incluye
 * el relleno y el borde de la caja.
 */
export function altoCaja({ scrollHeight, altoLinea, relleno }) {
  const minimo = altoLinea + relleno;
  const maximo = altoLinea * LINEAS_MAXIMAS + relleno;
  return { alto: Math.min(Math.max(scrollHeight, minimo), maximo), conScroll: scrollHeight > maximo };
}
