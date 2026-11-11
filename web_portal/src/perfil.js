import { API_BASE } from './config';
import { diaLocal, textoDia } from './notas';

// Perfil completo del portal (versión final, Fase 2). Lógica pura, probada en
// perfil.test.js.

export const resumenUrl = `${API_BASE}/api/especialista/resumen`;

export const INSTITUCION = 'Escuela Superior de Cómputo (ESCOM) · Instituto Politécnico Nacional';

/** Fecha de alta ("1 sep 2026") en hora de México; '—' si no se conoce. */
export const textoFechaAlta = (fecha) => (fecha ? textoDia(diaLocal(fecha)) : '—');

/** Conteos de la tarjeta "Tu actividad", en el orden en que se muestran. */
export function filasActividad(r) {
  return [
    { clave: 'pacientes', etiqueta: 'Pacientes vinculados', valor: r.pacientes_vinculados },
    { clave: 'mensajes', etiqueta: 'Mensajes enviados', valor: r.mensajes_enviados },
    { clave: 'notas', etiqueta: 'Notas clínicas registradas', valor: r.notas_registradas },
    { clave: 'exportaciones', etiqueta: 'Reportes exportados este mes', valor: r.exportaciones_mes },
  ].map((f) => ({ ...f, valor: Number.isFinite(f.valor) ? f.valor : 0 }));
}
