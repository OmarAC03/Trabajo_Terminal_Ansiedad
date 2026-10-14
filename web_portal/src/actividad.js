// Actividad de medición de los pacientes, para el Dashboard y la sección
// Pacientes. Funciones puras sobre las filas de GET /api/pacientes: sin React
// ni red, se prueban con Jest (actividad.test.js).
//
// Muestran ACTIVIDAD (cuándo y cuánto midió cada paciente), nunca un estado:
// el semáforo de umbrales fijos se retiró porque no tiene fundamento
// (DESARROLLO_FUNDAMENTADO.md §2), y la clasificación Normal/Elevados/Altos
// llegará con la línea base de cada paciente (M3).
//
// Campos que usan (null / 0 si el paciente nunca midió): `ultima_sesion`
// (fecha_inicio de su sesión más reciente), `ultima_sesion_origen` y
// `sesiones_7d` (contado por el backend con su reloj).

// Debe coincidir con DIAS_ACTIVIDAD del backend (server.js).
export const DIAS_ACTIVIDAD = 7;

const DIA_MS = 24 * 60 * 60 * 1000;

const sesiones7d = (p) => Number(p.sesiones_7d) || 0;

/** Indicadores del grupo: nadie se clasifica, solo se cuenta actividad. */
export function resumenActividad(pacientes) {
  const midieron = pacientes.filter((p) => sesiones7d(p) > 0).length;
  return {
    total: pacientes.length,
    conSesiones: pacientes.filter((p) => p.ultima_sesion).length,
    midieron,
    sinMedir: pacientes.length - midieron,
    sesiones: pacientes.reduce((suma, p) => suma + sesiones7d(p), 0),
  };
}

/** Última sesión más reciente primero; quien nunca midió al final, por nombre. No es un ranking de ansiedad. */
export const ordenarPorActividad = (pacientes) =>
  [...pacientes].sort(
    (a, b) =>
      new Date(b.ultima_sesion || 0) - new Date(a.ultima_sesion || 0) ||
      a.nombre.localeCompare(b.nombre)
  );

/** Los `max` pacientes que midieron más recientemente. */
export const actividadReciente = (pacientes, max = 5) =>
  ordenarPorActividad(pacientes.filter((p) => p.ultima_sesion)).slice(0, max);

// Grupos por la fecha de la última sesión, en el orden en que se muestran.
export const GRUPOS_RECENCIA = [
  { clave: 'hoy', texto: 'Hoy' },
  { clave: 'semana', texto: `En los últimos ${DIAS_ACTIVIDAD} días` },
  { clave: 'antes', texto: `Hace más de ${DIAS_ACTIVIDAD} días` },
  { clave: 'nunca', texto: 'Sin sesiones' },
];

/** Grupo de un paciente: 'hoy' (mismo día, hora local), 'semana', 'antes' o 'nunca'. */
export function grupoRecencia(paciente, ahora = Date.now()) {
  if (!paciente.ultima_sesion) return 'nunca';
  const fecha = new Date(paciente.ultima_sesion);
  if (fecha.toDateString() === new Date(ahora).toDateString()) return 'hoy';
  return ahora - fecha.getTime() <= DIAS_ACTIVIDAD * DIA_MS ? 'semana' : 'antes';
}

/** Cuántos pacientes caen en cada grupo (cada uno cuenta una vez, por su última sesión). */
export const conteoRecencia = (pacientes, ahora = Date.now()) =>
  GRUPOS_RECENCIA.map((g) => ({
    ...g,
    valor: pacientes.filter((p) => grupoRecencia(p, ahora) === g.clave).length,
  }));

// Filtro de la sección Pacientes: null = todos.
export const FILTROS_ACTIVIDAD = [
  { clave: null, texto: 'Todos' },
  { clave: 'midieron', texto: `Midieron en ${DIAS_ACTIVIDAD} días` },
  { clave: 'sin-medir', texto: `Sin sesiones en ${DIAS_ACTIVIDAD} días` },
];

export function coincideFiltroActividad(paciente, filtro) {
  if (filtro === 'midieron') return sesiones7d(paciente) > 0;
  if (filtro === 'sin-medir') return sesiones7d(paciente) === 0;
  return true;
}
