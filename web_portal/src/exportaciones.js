import { API_BASE } from './config';
import { textoDia } from './notas';

// Sección Reportes del portal (versión final, Fase 2): historial de
// exportaciones del propio especialista, leído de la bitácora
// (GET /api/especialista/exportaciones). Lógica pura, probada en
// exportaciones.test.js. (El componente es Reportes.js; este archivo no se
// llama reportes.js para no chocar con él en Windows.)

export const exportacionesUrl = `${API_BASE}/api/especialista/exportaciones`;

export const SIN_VINCULO = '(ya no vinculado)';

const ZONA_HORARIA = 'America/Mexico_City';

/** "10 nov 2026, 14:05" en hora de México. */
export function fechaHora(fecha) {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('es-MX', {
      timeZone: ZONA_HORARIA, day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
    }).formatToParts(new Date(fecha)).map((x) => [x.type, x.value])
  );
  return `${p.day} ${p.month.replace('.', '')} ${p.year}, ${p.hour}:${p.minute}`;
}

/** Una fila del historial con los textos que muestra la tabla. */
export function filaHistorial(f) {
  return {
    clave: f.id,
    fecha: fechaHora(f.fecha),
    paciente: f.vinculado && f.paciente_nombre ? f.paciente_nombre : SIN_VINCULO,
    vinculado: Boolean(f.vinculado),
    formato: f.formato === 'csv' ? 'CSV' : f.formato === 'pdf' ? 'PDF' : '—',
    identificacion: f.seudonimizado ? 'Seudonimizado' : 'Con nombre',
    periodo: f.desde && f.hasta ? `${textoDia(f.desde)} – ${textoDia(f.hasta)}` : '—',
  };
}

/** Pacientes para el selector de "Exportar", por nombre. */
export const pacientesParaExportar = (pacientes) =>
  [...(pacientes || [])].sort((a, b) => String(a.nombre).localeCompare(String(b.nombre), 'es'));
