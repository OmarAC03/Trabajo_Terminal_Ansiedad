// Reporte de un paciente: CSV y vista de impresión (Bloque 2, paso 4:
// WEB-RF-29 / RNF-WEB-08). Funciones puras, sin React ni red: se prueban con
// Jest (reporte.test.js). Los datos vienen de
// GET /api/pacientes/:id/reporte (backend/reporte.js), que ya quita lo que no
// va en la versión seudonimizada (decisión D3). Sin bibliotecas GPL/AGPL: el
// CSV se arma aquí y el PDF es el diálogo de impresión del navegador.
//
// "Seudonimizado", nunca "anónimo": el identificador P-xxxxxxxx se puede
// recalcular a partir del uid.

import { API_BASE } from './config';
import { diaLocal } from './notas';
import { textoEstado, textoEtapa } from './semaforo';
import { textoSeveridad } from './gad7';
import { textoTipo } from './marcadores';
import { textoContextoEva, textoOrigen } from './sesiones';

export const reporteUrl = (pacienteId) => `${API_BASE}/api/pacientes/${pacienteId}/reporte`;

export const DIAS_MAXIMOS = 366;
const DIA_MS = 24 * 60 * 60 * 1000;
const ZONA_HORARIA = 'America/Mexico_City';

/** Últimos 30 días (inclusive hoy), en días locales. */
export function rangoPorDefecto(ahora = new Date()) {
  return { desde: diaLocal(new Date(ahora.getTime() - 29 * DIA_MS)), hasta: diaLocal(ahora) };
}

/** Mensaje si el periodo no es válido; '' si está bien. */
export function errorRango({ desde, hasta }) {
  if (!desde || !hasta) return 'Elige el periodo completo.';
  if (desde > hasta) return '"Desde" no puede ser posterior a "Hasta".';
  const dias = (Date.parse(`${hasta}T00:00:00Z`) - Date.parse(`${desde}T00:00:00Z`)) / DIA_MS + 1;
  if (dias > DIAS_MAXIMOS) return `El periodo no puede pasar de ${DIAS_MAXIMOS} días.`;
  return '';
}

export const parametrosReporte = ({ desde, hasta }, formato, seudonimizado) => ({
  desde, hasta, formato, seudonimizado: seudonimizado ? 'true' : 'false',
});

const formatoLocal = new Intl.DateTimeFormat('en-CA', {
  timeZone: ZONA_HORARIA, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
});

/** '2026-10-05T15:00:00Z' → '2026-10-05 09:00' (Ciudad de México). */
export function fechaLocal(iso) {
  if (!iso) return '';
  const p = Object.fromEntries(formatoLocal.formatToParts(new Date(iso)).map((x) => [x.type, x.value]));
  return `${p.year}-${p.month}-${p.day} ${p.hour}:${p.minute}`;
}

// --- CSV ---
// Formato largo: una fila por dato (registro, fecha, variable, valor,
// unidad), fácil de filtrar o de pasar a R/Python. UTF-8 con BOM (para que
// Excel respete los acentos) y CRLF.

const ENCABEZADO_CSV = ['paciente', 'registro', 'fecha_utc', 'fecha_local', 'variable', 'valor', 'unidad'];

/**
 * Un campo de CSV. Los textos van entre comillas, y si empiezan con = + - @
 * tabulador o retorno se les antepone ' para que una hoja de cálculo no los
 * ejecute como fórmula (inyección CSV). Los números van tal cual (un -3 es un
 * número, no una fórmula).
 */
export function campoCsv(valor) {
  if (valor == null || valor === '') return '';
  if (typeof valor === 'number') return Number.isFinite(valor) ? String(valor) : '';
  if (typeof valor === 'boolean') return valor ? 'true' : 'false';
  let texto = String(valor);
  if (/^[=+\-@\t\r]/.test(texto)) texto = `'${texto}`;
  return `"${texto.replace(/"/g, '""')}"`;
}

function filasReporte(r) {
  const filas = [];
  const agregar = (registro, fecha, variable, valor, unidad = '') => {
    if (valor === undefined) return; // campo que no viene (p. ej. seudonimizado)
    filas.push([r.paciente.id, registro, fecha, fechaLocal(fecha), variable, valor, unidad]);
  };
  // Con identificación: quién es, en filas propias (la columna `paciente`
  // siempre es el identificador, para que el formato sea el mismo).
  agregar('paciente', null, 'nombre', r.paciente.nombre);
  agregar('paciente', null, 'email', r.paciente.email);
  agregar('paciente', null, 'especialista', r.especialista?.nombre);
  for (const s of r.sesiones) {
    const f = s.fecha_inicio;
    agregar('sesion', f, 'origen', s.origen);
    agregar('sesion', f, 'duracion_total', s.duracion_total_seg, 's');
    agregar('sesion', f, 'duracion_valida', s.duracion_valida_seg, 's');
    agregar('sesion', f, 'hrv_rmssd', s.hrv_rmssd, 'ms');
    agregar('sesion', f, 'fc_promedio', s.bpm_promedio, 'lpm');
    agregar('sesion', f, 'fc_min', s.bpm_min, 'lpm');
    agregar('sesion', f, 'fc_max', s.bpm_max, 'lpm');
    agregar('sesion', f, 'spo2_promedio', s.spo2_promedio, '%');
    agregar('sesion', f, 'indice_calidad', s.indice_calidad, '0-1');
    agregar('sesion', f, 'eva', s.eva_valor, '0-100');
    agregar('sesion', f, 'eva_contexto', s.eva_contexto);
    agregar('sesion', f, 'estado_vs_linea_base', s.estado);
    agregar('sesion', f, 'etapa_linea_base', s.etapa);
  }
  for (const g of r.gad7) {
    agregar('gad7', g.fecha_respuesta, 'puntaje', g.puntaje, '0-21');
    agregar('gad7', g.fecha_respuesta, 'severidad', g.severidad);
  }
  for (const m of r.marcadores) {
    agregar('marcador', m.fecha, 'tipo', m.tipo);
    agregar('marcador', m.fecha, 'descripcion', m.descripcion);
  }
  return filas;
}

/** Texto completo del CSV (con BOM). */
export function csvDesdeReporte(r) {
  const lineas = [ENCABEZADO_CSV, ...filasReporte(r)].map((fila) => fila.map(campoCsv).join(','));
  return `﻿${lineas.join('\r\n')}\r\n`;
}

/** Nombre del archivo: el identificador seudonimizado, nunca el nombre. */
export const nombreArchivo = (r, extension) =>
  `reporte_${r.paciente.id}_${r.periodo.desde}_${r.periodo.hasta}${r.seudonimizado ? '_seudonimizado' : ''}.${extension}`;

// --- Textos de la vista de impresión ---

export const textoEstadoReporte = (s) => (s.estado ? textoEstado(s.estado) : 'Sin estado');
export const textoEtapaReporte = (s) => (s.etapa ? textoEtapa(s.etapa) : '—');
export { textoSeveridad, textoTipo, textoContextoEva, textoOrigen };
